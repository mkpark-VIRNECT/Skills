# issue-family-goal stacked PR 재현 시나리오

저장소 루트에서 실행한다. 이 시나리오는 parent [#2](https://github.com/mkpark-VIRNECT/Skills/issues/2)의 direct child `#3 → #4 → #5 → #6`과 diamond dependency를 사용하며 merge와 issue close는 수행하지 않는다.

## 1. Goal 수명주기

다음 요청으로 시작한다.

```text
[issue-family-goal](plugins/virnect-skills/skills/issue-family-goal/) https://github.com/mkpark-VIRNECT/Skills/issues/2 이슈를 작업해
```

| 시작 상태 | 기대 결과 |
| --- | --- |
| goal 없음 | live snapshot을 제시하고 승인 전에는 goal을 만들지 않는다. |
| 같은 repo/parent의 active goal | 새 goal을 만들지 않고 고정 child와 진행 상태를 재개한다. |
| 다른 active goal | 기존 goal을 덮어쓰지 않고 충돌을 보고한다. |
| direct child 또는 dependency 변경 | 새 graph를 자동 편입하지 않고 기존 snapshot과 차이를 보여준 뒤 승인을 받는다. |

snapshot 승인 응답은 다음과 같다.

```text
goal 등록 승인
```

기대 objective에는 repository, parent, 고정 child, 순차 stacked PR, latest-HEAD review와 최종 ancestry 감사, merge 제외가 포함된다.

## 2. 고정 snapshot 확인

```powershell
$Repo = "mkpark-VIRNECT/Skills"
$Parent = 2
$Children = 3, 4, 5, 6
$Preflight = "plugins/virnect-skills/skills/issue-management/scripts/gh-issue-preflight.ps1"

gh repo view $Repo --json nameWithOwner,defaultBranchRef
gh api --paginate "repos/$Repo/issues/$Parent/sub_issues?per_page=100" --jq '.[].number'
$Children | ForEach-Object { & $Preflight -Issue $_ -Mode Full -Json }
```

기대 결과:

```text
default branch: master
native child order: #3, #4, #5, #6
#4 blocked-by #3
#5 blocked-by #3
#6 blocked-by #4, #5
topological/stack order: #3 → #4 → #5 → #6
```

`Full` 결과가 `partial=true`이거나 snapshot 밖 open blocker가 있으면 착수하지 않는다.

## 3. 순차 stack 실행

첫 child만 `master`에서 시작하고 이후 child는 직전 review-clear PR branch에서 시작한다.

```text
master
└─ #3 branch / PR
   └─ #4 branch / PR
      └─ #5 branch / PR
         └─ #6 branch / PR
```

각 child의 branch는 첫 push 전에 연결한다.

```powershell
gh issue develop <issue> --base <stack-base-branch> --name <head-branch>
gh issue develop --list <issue>
```

PR은 `<stack-base-branch>`를 base로 만들고 source child만 close한다.

```powershell
gh pr create --draft --base <stack-base-branch> --head <head-branch> --assignee '@me' --title '<한국어 제목>' --body '<요약과 검증, Closes #child, Refs #2>'
gh pr view <pr> --json baseRefName,headRefName,headRefOid,assignees,closingIssuesReferences,isDraft
```

GitHub가 PR 생성 뒤 `linkedBranches`에서 기존 branch를 제거한 경우 같은 이름으로 `gh issue develop`을 재시도하지 않는다. PR의 `closingIssuesReferences`, 정확한 `headRefName`/`headRefOid`, PR 생성 전 연결 결과를 Development 증거로 남긴다.

반대로 predecessor branch를 base로 한 stacked PR은 본문에 full repository `Closes`를 넣어도 `closingIssuesReferences`가 비고 linked branch만 유지될 수 있다. 이때 strict postcondition을 통과한 것으로 간주하지 않는다. platform-equivalent fallback을 goal snapshot에서 명시적으로 승인받기 전까지 PR은 Draft, issue는 `Issue Review`로 유지한다.

## 4. Blocker 판정

| blocker | 처리 |
| --- | --- |
| 고정 child 안의 predecessor | predecessor PR의 remote HEAD와 reviewed SHA가 같고, review thread/blocking review가 0건이며 stack base가 그 SHA를 포함할 때만 해제한다. |
| snapshot 밖 issue 또는 PR | goal-local 예외를 적용하지 않는 hard stop이다. |
| preflight 조회 누락 | `partial=false`가 될 때까지 hard stop이다. |
| 기존 PR의 base/ancestry 불일치 | retarget, rebase, force-push하지 않고 보고한다. |

goal-local predecessor를 해제하기 전에 다음을 확인한다.

```powershell
git fetch origin
git merge-base --is-ancestor <reviewed-predecessor-sha> "origin/<stack-base-branch>"
gh pr view <predecessor-pr> --json headRefName,headRefOid,isDraft,mergeStateStatus,reviews
```

## 5. Latest-HEAD review와 최종 감사

각 PR의 독립 review는 현재 `headRefOid`와 같은 commit을 대상으로 해야 한다. 작성자 본인 PR이면 `COMMENT` review를 사용한다.

```powershell
gh pr view <pr> --json headRefOid,reviews,reviewDecision,mergeStateStatus,isDraft
gh api graphql -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){headRefOid reviewThreads(first:100){nodes{isResolved}} reviews(last:100){nodes{state commit{oid}}}}}}' -F owner='mkpark-VIRNECT' -F repo='Skills' -F number=<pr>
```

완료 전 child마다 아래 항목을 다시 확인한다.

- source issue의 closing PR과 정확한 head branch/SHA
- 계획한 PR base
- predecessor reviewed SHA가 successor branch의 ancestor인지 여부
- latest HEAD 대상 독립 review
- unresolved review thread 0건
- `CHANGES_REQUESTED` review 0건
- assignee, closing issue, Ready 판단, `mergeStateStatus=CLEAN`

연속 ancestry는 stack의 모든 인접 branch에 대해 실행한다.

```powershell
git fetch origin
git merge-base --is-ancestor "origin/<previous-branch>" "origin/<next-branch>"
```

네 child가 모두 review-clear이고 연속 ancestry가 통과한 뒤에만 goal을 complete로 표시한다. PR merge, issue close, parent 직접 구현은 이 시나리오의 범위가 아니다.
