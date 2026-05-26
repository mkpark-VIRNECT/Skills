# GitHub Relationship 조회 정책

ProjectV2와 issue Relationship은 GraphQL 비용과 stale 상태 오판을 줄이기 위해 최소 조회를 기본으로 한다.

## GraphQL 사용 경계

REST/GitHub 앱/`gh issue`로 가능한 repo 정보, 템플릿/문서 확인, 중복 검색, 이슈 생성/수정, 본문/댓글, label, assignee, milestone 처리는 GraphQL로 대체하지 않는다.

GraphQL은 다음에만 사용한다.

- ProjectV2 item/status 식별자 확인과 status 변경/검증.
- `addSubIssue`, `addBlockedBy`.
- touched issue의 1-depth relationship 검증.

기본 금지:

- Project fields 전체, project item 전체, project view 전체 조회.
- 매 작업마다 schema introspection 반복.
- touched issue 밖의 관계 그래프 확장 조회.

같은 작업 묶음에서는 Project id, status field id, option id, issue node id를 한 번 조회해 재사용한다. `addSubIssue`와 `addBlockedBy`는 지원 mutation으로 간주하고, 실패할 때만 권한, API 지원, validation 문제를 보고한다.

## 기본 순서

1. 사용자가 지정한 issue number 또는 URL은 direct lookup으로 조회한다.
2. target issue의 1-depth relationship만 조회한다.
3. 연결된 이슈와 target issue에서 active PR 후보를 좁힌 뒤, `closingIssuesReferences`나 `issue-<번호>` 브랜치명으로 실제 연결된 PR만 남긴다.
4. 실제 연결된 후보 PR에 대해서만 changed files를 조회한다.
5. mutation 직전과 `In Progress` 전환 직전에는 live 상태를 다시 확인한다.

## 최소 relationship query

```graphql
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      id
      number
      title
      state
      url
      parent { id number title state url }
      subIssues(first: 20) { nodes { id number title state url } }
      blockedBy(first: 20) { nodes { id number title state url } }
      blocking(first: 20) { nodes { id number title state url } }
      projectItems(first: 20) {
        nodes {
          id
          project { title number }
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2FieldCommon { name } }
                name
                optionId
              }
            }
          }
        }
      }
    }
  }
  rateLimit { cost remaining resetAt }
}
```

## Mutation 규칙

- `addSubIssue`와 `addBlockedBy` 실행 전에는 이미 같은 관계가 있는지 먼저 조회한다.
- 후속 이슈 `B`가 선행 이슈 `A`를 기다리면 `addBlockedBy(issueId: B, blockingIssueId: A)` 방향으로 설정한다.
- GitHub connector에 relationship 전용 도구가 없다는 이유만으로 본문 fallback을 선택하지 않는다. `gh api graphql` mutation이 권한, API 지원, validation 문제로 실패한 경우에만 fallback한다.
- 관계 설정 후 검증은 target issue의 relationship field와 Project item만 다시 조회한다.
- GraphQL 조회/변경은 병렬 실행하지 않는다.
- `gh pr list --search <issue-number>` 결과는 본문 숫자 언급만으로도 잡힐 수 있으므로, 결과를 active PR 충돌 후보로 바로 사용하지 않는다.

## 캐시 규칙

- 같은 턴의 중복 조회를 줄이는 캐시는 허용한다.
- 캐시해도 되는 값은 repo owner/name, project number, Project field id, status option id, issue node id, project item id 같은 식별자에 한정한다.
- Project status 현재값, 최신 issue/PR comment, PR head SHA, changed files, relationship graph, local diff, preflight decision은 drift가 잦으므로 착수 결정과 mutation 직전에는 캐시를 쓰지 않는다.
- 오래된 캐시와 live 조회가 다르면 live 조회를 우선한다.

## Preflight mode 규칙

- `Full`은 기존 기본 동작이며 보고, PR 본문, 리뷰 위임, 병렬 작업 판단에 필요한 완전 컨텍스트를 제공한다. `blockedBy`가 있어도 PR 후보/파일 조회를 생략하지 않는다.
- `Startup`은 빠른 착수 후보 판단용이다. 열린 `blockedBy`가 있으면 target issue PR만 확인하고 관련 이슈 PR 파일 조회를 생략할 수 있다.
- `StatusTransition`은 `In Progress` 전환 직전 live gate다. open blocker와 active PR 후보를 다시 확인하되, PR changed files가 필요하면 `PrConflict` 또는 `Full`을 별도로 사용한다.
- `PrConflict`는 PR 발행 직전 파일 충돌 gate다. local diff 상태가 `ok-changed`일 때만 active PR changed files와 overlap을 판단한다.
- `partial=true` 또는 `skippedLookups`가 있는 결과는 조회 생략이 있었다는 뜻이므로 `softConflicts=[]`나 `overlappingPrs=[]`를 충돌 없음으로 해석하지 않는다.
