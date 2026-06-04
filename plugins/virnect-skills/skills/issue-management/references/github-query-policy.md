# GitHub 조회 및 ProjectV2 정책

이 문서는 이슈 검색, ProjectV2 Status/Size/Estimate 설정, relationship GraphQL 조회/검증이 필요할 때 읽는다.
GraphQL 비용과 stale 상태 오판을 줄이기 위해 touched issue 중심의 최소 조회를 기본으로 한다.

## 조회 순서

1. 사용자가 지정한 issue number 또는 URL은 direct lookup으로 조회한다.
   - GitHub URL 또는 issue number가 있으면 GitHub 앱의 issue fetch, `gh issue view <number>`, REST lookup 중 하나로 해당 이슈만 조회한다.
   - 이 경우 repo-wide search를 먼저 실행하지 않는다.
2. 중복 후보 검색은 좁게 시작한다.
   - `gh issue list --search` 또는 GitHub 앱 issue search를 우선 사용한다.
   - 검색어는 핵심 keyword 1-3개로 나누고, 복잡한 `OR`/`AND` 조합은 피한다.
   - 기본 limit은 10, 많아도 20으로 제한한다.
   - open issue를 먼저 보고, 필요할 때만 closed issue를 추가 조회한다.
3. 후보 상세 조회는 선별한다.
   - search 결과 전체의 comments/body를 모두 fetch하지 않는다.
   - 제목, label, milestone, updated time, 코드 경로로 후보를 먼저 줄이고, 상위 3개 이내만 본문/댓글을 자세히 읽는다.
   - 후보가 20개를 넘거나 판단이 계속 애매하면 추가 조회를 반복하지 말고 후보 목록과 판단 기준을 보고한다.
4. mutation 직전과 `In Progress` 전환 직전에는 live 상태를 다시 확인한다.

## GraphQL 사용 경계

REST/GitHub 앱/`gh issue`로 가능한 repo 정보, 템플릿/문서 확인, 중복 검색, 이슈 생성/수정, 본문/댓글, label, assignees, milestone 처리는 GraphQL로 대체하지 않는다.

GraphQL은 다음에만 사용한다.

- ProjectV2 item, Status, Size, Estimate 식별자 확인과 field 변경/검증.
- `addSubIssue`, `addBlockedBy`.
- touched issue의 1-depth relationship 검증.

기본 금지:

- Project fields 전체, project item 전체, project view 전체 조회.
- 매 작업마다 schema introspection 반복.
- touched issue 밖의 관계 그래프 확장 조회.
- `gh project field-list`를 status 확인용으로 반복 실행하는 것.

같은 작업 묶음에서는 Project id, Status/Size/Estimate field id, option id, issue node id, project item id를 한 번 조회해 재사용한다.
Project Status/Size/Estimate 현재값, 최신 issue/PR comment, PR head SHA, changed files, relationship graph, local diff, preflight decision은 mutation 직전 live 조회를 우선한다.

## ProjectV2 필드 규칙

- Status, Size, Estimate field 이름, 타입, option id, field id는 mutation 직전 최소 GraphQL query로 확인한다.
- Status는 보통 `Todo`, `In Progress`, `Done`, `Issue Review`, `Backlog`, `Ready` 같은 single-select field다.
- `Backlog`는 사용자 지시나 repo 문서로 `Todo` 동등 상태임이 확인된 경우에만 사용할 수 있다.
- Size는 single-select일 수도 있고 저장소별 다른 이름이나 옵션을 쓸 수 있으므로, 최근 유사 이슈와 Project schema로 확인한다.
- Estimate는 시간 단위 숫자 field를 기본으로 보되, 실제 field 타입과 이름을 확인한다.
- ProjectV2 상태, Size, Estimate 변경 후에는 issue-level project item만 최소 GraphQL query로 다시 확인한다.
- `gh project item-add` 또는 `gh project item-edit` 출력만으로 완료 판정하지 않는다.

## 최소 issue/project/relationship query

```graphql
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      id
      number
      title
      state
      url
      assignees(first: 20) { nodes { login } }
      parent { id number title state url }
      subIssues(first: 20) { nodes { id number title state url } }
      blockedBy(first: 20) { nodes { id number title state url } }
      blocking(first: 20) { nodes { id number title state url } }
      projectItems(first: 20) {
        nodes {
          id
          project { id title number }
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2FieldCommon { id name } }
                name
                optionId
              }
              ... on ProjectV2ItemFieldNumberValue {
                field { ... on ProjectV2FieldCommon { id name } }
                number
              }
              ... on ProjectV2ItemFieldTextValue {
                field { ... on ProjectV2FieldCommon { id name } }
                text
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

저장소별 option id가 확인되어 있어도 실패하거나 Project schema가 바뀐 정황이 있으면 `projectV2.fields(first: 50)` query를 1회 실행한다.

## Relationship mutation 규칙

- `addSubIssue`와 `addBlockedBy` 실행 전에는 이미 같은 관계가 있는지 먼저 조회한다.
- 후속 이슈 `B`가 선행 이슈 `A`를 기다리면 `addBlockedBy(issueId: B, blockingIssueId: A)` 방향으로 설정한다.
- GitHub connector에 relationship 전용 도구가 없다는 이유만으로 본문 fallback을 선택하지 않는다.
- `gh api graphql` mutation이 권한, API 지원, validation 문제로 실패한 경우에만 fallback한다.
- 관계 설정 후 검증은 target issue의 relationship field와 Project item만 다시 조회한다.

## 충돌 후보 조회

- `gh pr list --search <issue-number>` 결과는 본문 숫자 언급만으로도 잡힐 수 있으므로 active PR 충돌 후보로 바로 사용하지 않는다.
- 연결된 이슈와 target issue에서 active PR 후보를 좁힌 뒤 `closingIssuesReferences`나 `issue-<번호>` 브랜치명으로 실제 연결된 PR만 남긴다.
- 실제 연결된 후보 PR에 대해서만 changed files를 조회한다.

## Preflight mode 규칙

- `Full`은 보고, PR 본문, 리뷰 위임, 병렬 작업 판단에 필요한 완전 컨텍스트다. `blockedBy`가 있어도 PR 후보/파일 조회를 생략하지 않는다.
- `Startup`은 빠른 착수 후보 판단용이다. 열린 `blockedBy`가 있으면 target issue PR만 확인하고 관련 이슈 PR 파일 조회를 생략할 수 있다.
- `StatusTransition`은 `In Progress` 전환 직전 live gate다. open blocker와 active PR 후보를 다시 확인하되, PR changed files가 필요하면 `PrConflict` 또는 `Full`을 별도로 사용한다.
- `PrConflict`는 PR 발행 직전 파일 충돌 gate다. local diff 상태가 `ok-changed`일 때만 active PR changed files와 overlap을 판단한다.
- `partial=true` 또는 `skippedLookups`가 있는 결과는 조회 생략이 있었다는 뜻이므로 `softConflicts=[]`나 `overlappingPrs=[]`를 충돌 없음으로 해석하지 않는다.

## 비용 및 캐시 규칙

- 비용이 커질 수 있는 query에는 가능하면 `rateLimit { cost remaining resetAt }`를 함께 요청한다.
- remaining이 낮거나 실패가 반복되면 즉시 중단하고, 어떤 조회가 필요했는지와 사용자가 재시도할 수 있는 다음 조치를 보고한다.
- GraphQL 조회/변경은 병렬 실행하지 않는다.
- 파일 읽기나 REST 성격의 작은 조회는 병렬화할 수 있지만, ProjectV2 GraphQL 조회/변경은 순차적으로 실행한다.
- 같은 턴의 중복 조회를 줄이는 캐시는 허용한다.
- 캐시해도 되는 값은 repo owner/name, project number, Project field id, option id, issue node id, project item id 같은 식별자에 한정한다.
- 오래된 캐시와 live 조회가 다르면 live 조회를 우선한다.
