# Relationship 정책

이 문서는 GitHub 이슈를 생성, 분해, 갱신할 때 Relationship을 선택하는 기준이다.
관계 판단이 단순하면 `SKILL.md`의 요약 규칙만 사용하고, 병렬 위임이나 선후행 판단이 애매할 때 이 문서를 읽는다.

## 우선순위

1. `duplicate/canonical`: 같은 root cause, 같은 데이터 계약, 같은 UI 흐름, 같은 PR 범위로 해결되는 항목은 하나의 canonical issue로 통합한다.
2. `parent/sub-issue`: 큰 작업을 독립 완료 기준이 있는 구현 단위로 나눌 때 사용한다.
3. `blocked-by`: 선행 작업, 정책 결정, 공통 계약, active PR merge 없이는 안전하게 착수할 수 없을 때 사용한다.
4. `related`: 순서 제약은 없지만 맥락이나 회귀 확인을 위해 함께 봐야 할 때 본문에만 기록한다.

## 선택 기준

| 상황 | 관계 | 처리 |
|------|------|------|
| 같은 버그 증상과 같은 root cause | canonical | 최신 맥락이 풍부한 open issue에 통합하고 중복 이슈는 duplicate 또는 related로 정리한다. |
| 같은 기능 묶음이지만 독립 완료 기준이 있음 | parent/sub-issue | 부모는 배경과 작업 순서를 담고, 하위 이슈는 바로 구현 가능한 범위와 검증을 담는다. |
| API/DTO/DB/protocol/공통 컴포넌트가 먼저 확정돼야 함 | blocked-by | 후속 이슈가 선행 이슈에 의해 blocked 되도록 설정한다. |
| 같은 화면, 모델, service, repository, generated file, E2E fixture를 active PR이 수정 중임 | blocked-by 또는 conflict-risk | 후속 작업이 선행 PR merge를 기다려야 하면 blocked-by를 설정하고, 단순 충돌 위험이면 본문과 PR에 위험 파일을 기록한다. |
| 관련 문맥만 공유하고 작업 순서가 없음 | related | GitHub relationship mutation은 만들지 않고 본문 `Related`에만 남긴다. |

## Fallback 규칙

- GitHub connector에 relationship 전용 도구가 없다는 것은 fallback 사유가 아니다.
- parent/sub-issue와 blocked-by는 `gh api graphql`의 `addSubIssue`, `addBlockedBy`를 먼저 사용한다.
- 권한, API 지원, validation 문제로 GraphQL mutation이 실패한 경우에만 본문 `관계 및 작업 순서` 섹션에 fallback한다.
- 단순 참고 관계는 native relationship을 만들지 않고 본문 `Related`에만 둔다.

## 방향 규칙

후속 이슈 `B`가 선행 이슈 `A`를 기다리면 다음 방향으로 설정한다.

```powershell
gh api graphql -f query='
mutation($issueId: ID!, $blockingIssueId: ID!) {
  addBlockedBy(input: {
    issueId: $issueId
    blockingIssueId: $blockingIssueId
  }) {
    issue { number }
    blockingIssue { number }
  }
}' -F issueId="<B_node_id>" -F blockingIssueId="<A_node_id>"
```

`blockedBy`가 열려 있는 이슈는 `Todo`라도 착수 가능하지 않다. PR Loop는 열린 blocker가 모두 닫히거나 merge된 뒤에만 `In Progress`로 전환한다.

## 충돌 판정 신뢰도

| 근거 | 신뢰도 |
|------|--------|
| active PR 실제 changed files와 local diff가 겹침 | 높음 |
| 같은 PR/issue relationship이 있고 공통 계약 파일을 수정함 | 높음 |
| 이슈 본문에 같은 파일 경로, 화면, DTO, service가 명시됨 | 중간 |
| label, 제목, 도메인 키워드만 겹침 | 낮음 |

낮은 신뢰도의 충돌은 blocked-by를 바로 만들기보다 `Related`와 작업 노트에 남기고, 착수 직전 preflight로 다시 확인한다.
