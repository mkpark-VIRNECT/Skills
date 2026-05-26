---
name: issue-management
description: "요구사항을 GitHub 이슈로 등록하거나 기존 이슈를 갱신하는 이슈 관리 스킬. 중복 이슈 통합, parent/sub-issue 분해, blocked-by 관계, ProjectV2 상태, milestone, assignee, labels, 작업 이유·목적·계획·완료 기준·검증 계획을 정리해야 할 때 사용한다. GraphQL 비용을 낮게 유지하면서 저장소별 이슈/프로젝트 관례를 현재 repo에서 확인해 적용한다. 새 이슈 생성 또는 본문·범위·계획의 실질 갱신 전에는 등록 전 의도 확인 gate로 개발 의도, 범위, 성공 기준, 검증 방식을 완전히 이해할 때까지 한 번에 하나씩 질문한다."
---

# Issue Management

요구사항을 바로 작업 가능한 GitHub 이슈로 정리하고, 이슈 생성 또는 실질 갱신 전에 개발 의도를 완전히 이해한다.
이슈 생성, 이슈 갱신, 하위 이슈 분리, Project 상태 변경, relationship 설정을 하나의 흐름으로 처리한다.

## 핵심 원칙

- 사용자에게 보이는 이슈 제목, 본문, 코멘트, 보고는 저장소 지침과 현재 대화 언어에 맞춘다.
- 이슈 본문에는 `작업 이유`, `목적`, `작업 계획`, `완료 기준`, `검증 계획`을 포함한다.
- `작업 이유`는 왜 지금 이 작업이 필요한지 요구사항과 관측 근거를 연결해 쓴다.
- `목적`은 작업 완료 후 시스템이 어떻게 동작해야 하는지 검증 가능한 상태로 쓴다.
- `작업 계획`은 구현자가 바로 착수할 수 있도록 파일, 계층, API, 검증 경로를 가능한 한 구체적으로 쓴다.
- 새 이슈 생성 또는 본문·범위·계획을 바꾸는 실질 갱신 전에는 개발 의도 확정 조건을 모두 충족한다: 작업 이유, 목적/성공 기준, scope/non-scope, API/UI/data contract, 우선순위, 완료 기준, 검증 계획, 관계/의존성, 필수 GitHub 메타데이터.
- 같은 요구사항의 이슈가 이미 있거나, 같은 root cause와 같은 작업 범위로 해결되는 경우에는 canonical issue로 묶는다.
- UI 레이아웃이나 데이터 흐름이 중요한 이슈에는 간단한 ASCII 레이아웃이나 흐름도를 추가한다.
- GitHub 이슈 조회는 비용이 낮은 direct lookup과 제한된 search를 먼저 사용하고, GraphQL은 ProjectV2와 Relationship처럼 필요한 최소 범위에만 사용한다.
- 사실, 추론, 사용자 확인 필요 사항을 섞지 않는다. 확실하지 않은 내용은 질문으로 분리하고, 답이 해소되기 전에는 새 이슈 생성이나 실질 갱신을 하지 않는다.
- assignee, Project, milestone, label은 저장소 관례나 사용자 지시가 있을 때 설정한다. 관례를 확인할 수 없으면 지어내지 말고 미설정 사유를 보고한다.
- 프로젝트 상태는 이슈 본문 내용과 동기화한다. 각 이슈마다 GraphQL 조회 전에 `expectedStatus`를 먼저 정한다. 신규 등록 또는 실질 갱신에서는 질문이 남아 있으면 GitHub 변경을 중단하고, 질문 없이 바로 작업 가능하면 `Todo` 또는 동등한 상태로 둔다. 이미 존재하는 이슈에서 새 모호성이 발견되어 범위 확정 없이 관리성 표시가 필요할 때만 `Issue Review` 또는 저장소의 동등한 상태를 사용한다.
- `Backlog`는 상태 option 목록에 있더라도 사용자 지시나 repo 문서로 `Todo`의 동등 상태임이 확인된 경우에만 사용한다.
- 관계 판단이 애매하거나 병렬 작업 후보를 고를 때는 `references/relationship-policy.md`와 `scripts/gh-issue-preflight.ps1`를 사용한다.

## 질문 지침

- 계획의 모든 측면에 대해 사용자와 공유된 이해에 도달할 때까지 집요하게 질문한다.
- 설계 결정 트리의 각 분기를 따라가며 의존 관계가 있는 결정을 하나씩 순서대로 해소한다.
- 질문은 한 번에 하나만 한다.
- 각 질문에는 사용자가 선택하거나 수정할 수 있는 추천 답변을 함께 제시한다.
- 코드베이스 탐색으로 답할 수 있는 질문은 사용자에게 묻지 말고 먼저 코드, 문서, 기존 이슈, 설정을 확인한다.
- 사용자의 답변을 받은 뒤에는 새로 확정된 결정이 후속 결정, 하위 이슈 분리, 관계, 검증 계획에 미치는 영향을 다시 점검한다.

## 저장소 설정 확인

이 스킬은 저장소별 기본값을 하드코딩하지 않는다. 매번 현재 repo에서 다음을 확인한다.

1. 저장소와 기본 브랜치:
   - `gh repo view --json nameWithOwner,defaultBranchRef`
2. 이슈/PR 작성 규칙:
   - `AGENTS.md`, `.github/ISSUE_TEMPLATE*`, `.github/PULL_REQUEST_TEMPLATE*`, `README*`
3. 최근 유사 이슈의 필드 관례:
   - `gh issue list --state open --limit 10 --json number,title,labels,assignees,milestone,projectItems`
   - 필요한 경우에만 상위 후보 3개 이내의 본문과 댓글을 읽는다.
   - 최근 유사 이슈의 status는 참고값이다. 이슈 본문 내용과 사용자 확인 필요 여부로 판정한 `expectedStatus`를 덮어쓰지 않는다.
4. ProjectV2 상태명:
   - 자주 쓰는 상태명은 `Todo`, `In Progress`, `Done`, `Issue Review`, `Backlog`, `Ready` 같은 이름일 수 있다.
   - 정확한 option id는 mutation 직전 최소 GraphQL query로 확인한다.
   - `Backlog`는 `Todo`의 동등 상태로 명시 확인되지 않으면 선택하지 않는다.
5. milestone과 assignee:
   - 사용자의 명시 지시, repo 문서, 최근 유사 이슈를 우선한다.
   - 신규 등록 또는 실질 갱신에서 근거가 약하면 등록 전에 사용자에게 확인한다. 기존 이슈의 관리성 review 대기 표시에서는 미설정 사유를 보고할 수 있다.

## Relationship preflight mode

`scripts/gh-issue-preflight.ps1`는 기본 호출인 `-Issue <번호> -Json`에서 `Full` mode로 동작한다.
현재 repo가 아닌 저장소를 대상으로 할 때는 `-Repo owner/name`을 명시한다.
base branch가 기본 브랜치와 다르면 `-Base <branch>`를 명시한다.
Project 번호를 알고 있으면 `-ProjectNumber <number>`를 넘기고, 모르면 생략한다.

목적별 mode:

| Mode | 사용 시점 | 해석 규칙 |
|------|-----------|-----------|
| `Startup` | 착수 후보를 빠르게 거를 때 | 열린 `blockedBy`가 있으면 partial 결과일 수 있다. 최종 충돌 없음 근거로 쓰지 않는다. |
| `StatusTransition` | `In Progress` 전환 직전 | open blocker와 active PR 후보를 live로 다시 확인하는 gate로만 쓴다. |
| `PrConflict` | PR 발행 직전 또는 수정 범위 확대 후 | local diff와 active PR 파일 충돌을 확인한다. `localDiffStatus`가 불확실하면 ready로 해석하지 않는다. |
| `Full` | 이슈 보고, 작업 순서 판단, PR 본문, 리뷰 위임 | 완전 컨텍스트 조회다. `blockedBy`가 있어도 PR 후보/파일 조회를 생략하지 않는다. |

preflight 결과의 `partial=true` 또는 `skippedLookups`가 있으면 조회 생략이 있었다는 뜻이다.
이 경우 `softConflicts=[]`나 `overlappingPrs=[]`를 충돌 없음으로 해석하지 말고, 필요한 단계에서 `Full` 또는 `PrConflict`를 다시 실행한다.
`Startup`에서 열린 `blockedBy`가 있으면 기본적으로 target issue PR만 확인하며, 관련 이슈 PR까지 확인해야 하면 `-IncludePrsWhenBlocked`를 명시한다.
`localDiffStatus.status`는 `ok-empty`, `ok-changed`, `not-git-worktree`, `missing-origin-base`, `merge-base-failed` 중 하나이며, PR 파일 조회 생략은 `ok-empty`에서만 충돌 판단 근거로 사용할 수 있다.

같은 턴에서 재사용해도 되는 값은 repo owner/name, project number, Project field id, status option id, issue node id, project item id 같은 식별자에 한정한다.
Project status 현재값, 최신 issue/PR comment, PR head SHA, PR changed files, relationship graph, local diff, `ready`/`blocked`/`conflict-risk` 같은 최종 decision은 캐시하지 않는다.

## 작업 흐름

1. 요구사항과 최신 근거를 모은다.
   - 사용자가 특정 이슈 코멘트나 PR 코멘트를 지정하면 그 코멘트를 최신 truth source로 본다.
   - 관련 코드, 문서, 기존 이슈를 확인해 중복 이슈와 이미 결정된 계약을 먼저 찾는다.
   - 제목, 본문, 코멘트, labels, milestone, 관련 코드 경로를 기준으로 같은 요구사항 또는 같은 root cause의 이슈가 이미 있는지 검색하되, 아래 `GitHub 조회 비용 관리`의 제한을 지킨다.
   - 같은 문제로 판단되면 새 이슈를 만들지 말고 canonical issue를 정해 요구사항을 통합한다.
   - 요구사항이 너무 넓거나 여러 도메인을 건드리면 하위 이슈 분리를 기본값으로 검토한다.
2. 등록 전 의도 확인 gate를 통과한다.
   - 목적, 성공 기준, API/인터페이스 계약, 데이터 범위, 우선순위, 검증 방식, scope/non-scope, 관계/의존성 중 코드베이스나 기존 이슈에서 확인 가능한 사실을 먼저 확인한다.
   - 탐색 후에도 제품 의도나 구현 방향이 여러 갈래로 남으면 사용자에게 한 번에 하나씩 질문한다.
   - 각 질문에는 추천 답변과 그 답변을 추천하는 이유를 함께 제시한다.
   - 사용자가 답하면 그 결정이 후속 결정, 하위 이슈 분리, relationship, 완료 기준, 검증 계획에 미치는 영향을 다시 확인한다.
   - 새 이슈 생성 또는 본문·범위·계획의 실질 갱신 대상에 질문이 하나라도 남아 있으면 GitHub 생성/갱신 단계로 진행하지 않는다.
   - 이슈 생성 자체에 필요한 assignee, Project, milestone을 추론할 수 없으면 기존 유사 이슈에서 근거를 찾고, 그래도 확정할 수 없으면 등록 전에 사용자에게 확인한다.
   - 이미 존재하는 이슈에서 새 모호성을 발견했고 범위 확정 없이 review 대기 표시만 해야 하는 관리성 변경은 예외로 허용한다.
3. 이슈 구조를 결정한다.
   - 요구사항이 여러 개로 보여도 같은 원인, 같은 데이터 계약, 같은 UI 흐름, 같은 코드 변경으로 해결되면 하나의 이슈로 묶는다.
   - 이미 등록된 중복 이슈가 있으면 가장 최신 맥락이 풍부한 open issue를 canonical issue로 삼는다. 판단이 애매하면 더 오래된 open issue를 canonical issue로 삼고 최신 요구사항을 본문에 통합한다.
   - canonical issue가 아닌 중복 이슈에는 canonical issue 링크와 통합 이유를 코멘트로 남기고, 고유 완료 기준이 없으면 duplicate로 닫는다.
   - 고유 범위가 있으면 닫지 말고 related 또는 child issue로 남기고 본문에 관계를 명시한다.
   - Relationship은 `duplicate/canonical` 통합, `parent/sub-issue` 분해, `blocked-by` 선후행, 본문 `related` 참고 관계 순서로 판단한다.
   - 단일 작업이면 하나의 이슈로 등록한다.
   - 한 번에 처리하기 큰 작업이면 부모 이슈와 하위 이슈로 나눈다.
   - API 계약, 인터페이스, DB schema, 공통 DTO, protocol 같은 공통 선행 작업은 가장 먼저 독립 하위 이슈로 만든다.
   - 이후 하위 이슈는 서로 다른 도메인, 파일군, 검증 범위로 나누어 병렬 작업 시 conflict가 나지 않게 만든다.
   - 선행 이슈가 끝나야 착수 가능한 후속 이슈에는 `addBlockedBy(issueId: 후속_이슈, blockingIssueId: 선행_이슈)` 방향으로 blocked-by 관계를 설정한다.
4. 상태/관계 사전 계획을 작성한다.
   - 이 단계는 GitHub 이슈 생성/갱신과 GraphQL mutation 전에 완료한다.
   - 각 생성/갱신 대상 이슈마다 `expectedStatus`를 정한다. 신규 등록 또는 실질 갱신 대상은 의도가 확정된 경우에만 `Todo` 또는 동등한 상태로 둔다.
   - `Issue Review` 또는 동등한 상태는 이미 존재하는 이슈에서 새 모호성이 발견되어 review 대기 표시만 하는 관리성 변경에 한정한다.
   - 상태 결정 우선순위는 1) 이슈 본문 내용과 사용자 확인 필요 여부, 2) repo Project에 해당 상태 option이 실제 존재하는지, 3) 최근 유사 이슈의 field 관례다.
   - 최근 유사 이슈의 status는 참고값으로만 사용하고, 본문 기반 `expectedStatus`를 덮어쓰지 않는다.
   - 각 이슈마다 `expectedNativeRelations`를 정한다: parent/sub-issue, blocked-by, 또는 본문 `Related`.
   - native relationship을 만들 관계와 본문 `Related`로만 둘 관계를 분리한다. 순서 제약 없는 참고 관계는 GitHub relationship mutation을 만들지 않는다.
   - native relationship 실패 시 본문 fallback 허용 여부와 fallback 사유를 미리 적는다. fallback은 `gh api graphql`의 `addSubIssue` 또는 `addBlockedBy`가 권한, API 지원, validation 문제로 실패한 경우에만 허용한다.
   - GitHub connector에 relationship 전용 도구가 없다는 것만으로는 fallback하지 않는다.
5. 이슈 본문을 작성한다.
   - 아래 템플릿을 기준으로 하되, 빈 항목이나 장식적 문구는 남기지 않는다.
   - 중복 또는 동일 문제 이슈를 묶었다면 `관련 이슈 통합` 섹션에 canonical issue와 통합/닫힘/related 상태를 명시한다.
   - 선후행이나 병렬 충돌 회피가 있으면 `관계 및 작업 순서` 섹션에 blocked-by, blocking, related, 작업 시작 조건을 적는다.
   - UI 레이아웃 변경이 포함되면 `예상 UI 레이아웃` 섹션을 추가한다.
   - 데이터 흐름, replay, socket, migration처럼 처리 경계가 중요한 작업은 필요 시 `데이터 흐름도` 섹션을 추가한다.
   - 신규 등록 또는 실질 갱신 본문에는 `사용자 확인 필요 사항` 섹션을 남기지 않는다. 남은 질문은 등록 전에 채팅으로 해소한다.
   - 이미 존재하는 이슈를 review 대기로 표시하는 관리성 갱신에서만 본문 하단 `사용자 확인 필요 사항` 섹션을 사용한다.
6. GitHub 이슈를 생성하거나 갱신한다.
   - 새 이슈 생성 또는 실질 갱신 전에는 등록 전 의도 확인 gate가 통과됐고 남은 질문이 없는지 다시 확인한다.
   - 저장소 관례에 맞는 assignee, Project, milestone, label을 설정한다.
   - 하위 이슈를 만든 경우 부모/하위 연결과 blocked-by 관계를 설정한다.
   - GitHub 앱 도구에 relationship 전용 기능이 없어도 `gh api graphql`로 `addSubIssue`와 `addBlockedBy`를 시도한다.
   - `gh api graphql`이 권한, API 지원, validation 문제로 실패한 경우에만 본문 fallback을 적용하고 실패 사유를 보고한다.
7. Project 상태를 검증한다.
   - 각 이슈의 실제 상태가 사전 계획의 `expectedStatus`와 일치하는지 확인한다.
   - 질문이 없고 작업 범위가 명확하면 `Todo` 또는 동등한 상태.
   - 신규 등록 또는 실질 갱신 대상에서 질문이 있거나 목적/계획이 불확실하면 GitHub 변경을 중단하고 사용자에게 다음 질문 하나만 제시한다.
   - 기존 `Todo` 이슈에서 새 확인 필요 사항을 발견하면 본문 하단에 질문을 추가하고 review 상태로 변경할 수 있다. 단, 이 변경은 범위를 확정하지 않는 관리성 갱신이어야 한다.
8. native relationship을 검증한다.
   - 사전 계획의 `expectedNativeRelations`와 실제 parent/sub-issue, blocked-by, blocking 관계가 일치하는지 touched issue의 1-depth relationship만 조회해 확인한다.
   - 본문 `Related`로 둔 관계가 순서 제약 없는 참고 관계인지 다시 확인한다.
9. 결과를 보고한다.
   - 생성/갱신한 이슈 번호, 상태, 프로젝트, 마일스톤, 하위 이슈와 blocking 관계를 요약한다.
   - 각 이슈의 `expectedStatus`와 `actualStatus`를 함께 보고한다.
   - native parent/sub-issue와 native blocked-by 설정 여부를 보고한다.
   - fallback이 있었다면 GraphQL 실패 사유를 보고한다.
   - 비용 절감을 위해 생략한 조회 범위와 판단 근거를 보고한다.
   - GitHub 변경을 중단한 경우에는 다음으로 답해야 할 질문 하나와 추천 답변을 별도로 강조한다.

## 이슈 본문 템플릿

````markdown
## 작업 이유

- <요구사항, 버그 증상, 운영 필요성, 사용자 피드백 등 이 작업이 필요한 이유>

## 목적

- <완료 후 사용자가 확인할 수 있는 동작이나 상태>
- <API, UI, 데이터, 문서 계약이 어떻게 되어야 하는지>

## 관련 이슈 통합

- <중복 또는 동일 문제 이슈가 있을 때만 작성. canonical issue, 통합된 이슈, 닫은 이슈, related/child로 남긴 이슈와 이유>

## 관계 및 작업 순서

| 구분 | 이슈 | 이유 |
|------|------|------|
| Parent | <#부모> | <큰 작업 분해가 필요할 때만 작성> |
| Sub-issues | <#하위1, #하위2> | <하위 작업 목록> |
| Blocked by | <#선행> | <이 이슈가 기다리는 작업> |
| Blocking | <#후속> | <이 이슈 완료 후 시작할 작업> |
| Related | <#관련> | <순서 제약은 없지만 맥락상 관련된 작업> |

- 작업 시작 조건: <blocked-by 이슈가 모두 닫혀야 하는지, 특정 PR merge 이후인지, 또는 병렬 가능 조건>

## 예상 UI 레이아웃

```text
<UI 레이아웃 변경이 있을 때만 작성>
```

## 데이터 흐름도

```text
<데이터 흐름이나 처리 경계가 중요할 때만 작성>
```

## 작업 계획

1. <선행 조사 또는 계약 확정 작업>
2. <구현 작업. 가능하면 대상 모듈/파일/계층 포함>
3. <테스트, 문서, 회귀 확인 작업>

## 완료 기준

- <기능 동작 기준>
- <검증 통과 기준>

## 검증 계획

- <실행할 테스트, smoke, 빌드, 문서 검증 명령>
````

신규 등록 또는 실질 갱신 이슈에는 `사용자 확인 필요 사항` 섹션을 넣지 않는다. 남은 질문은 등록 전에 채팅에서 해소한다.
이미 존재하는 이슈에서 새 모호성이 발견되어 review 대기 표시만 하는 관리성 갱신에는 본문 하단에 `사용자 확인 필요 사항` 섹션을 추가할 수 있다. 이때 각 질문에는 추천 방향과 판단이 필요한 이유를 함께 쓴다.
중복 또는 동일 문제 이슈가 없으면 `관련 이슈 통합` 섹션을 제거한다.
UI 레이아웃 변경이 없으면 `예상 UI 레이아웃` 섹션을 제거한다.
데이터 흐름도가 요구사항 이해에 도움 되지 않으면 `데이터 흐름도` 섹션을 제거한다.
관계 또는 작업 순서 제약이 없으면 `관계 및 작업 순서` 섹션을 제거한다.
부모 이슈에는 전체 배경, 공통 계약, 하위 이슈 목록, 작업 순서를 포함하고, 실제 구현 상세는 하위 이슈에 둔다.

## Relationship 판단 기준

세부 기준은 `references/relationship-policy.md`를 우선 읽는다.

- 같은 root cause, 같은 데이터 계약, 같은 UI 흐름, 같은 PR 범위로 해결되면 새 이슈를 만들기보다 canonical issue로 통합한다.
- 독립 완료 기준이 있으면 별도 이슈로 남기고, 큰 작업의 구성 단위이면 parent/sub-issue 관계를 설정한다.
- API/DTO/DB/protocol/공통 컴포넌트/동일 화면 ownership처럼 선행 작업 없이는 안전하게 착수할 수 없으면 blocked-by 관계를 설정한다.
- 단순 참고나 회귀 확인 관계처럼 작업 순서가 없으면 GitHub relationship mutation을 만들지 말고 본문 `Related`에만 남긴다.
- GitHub connector에 relationship 전용 도구가 없어도 `gh api graphql`의 `addSubIssue`와 `addBlockedBy`를 먼저 시도한다. 본문 fallback은 해당 GraphQL mutation이 실패한 경우에만 허용한다.
- `Todo`는 작업 대기열 상태이고 착수 가능 상태와 다르다. `blockedBy`가 열려 있으면 `Todo`라도 병렬 작업 후보와 `In Progress` 전환 대상에서 제외한다.

## 하위 이슈 분리 기준

하위 이슈를 만들기 전에 먼저 동일 문제를 하나로 묶을 수 있는지 확인한다.
사용자의 요구가 문장상 분리되어 있어도 같은 root cause, 같은 API/DB/UI 계약, 같은 PR에서 해결해야 하는 변경이면 하위 이슈로 쪼개지 말고 canonical issue에 통합한다.

다음 중 하나라도 해당하면 하위 이슈 분리를 우선한다.

- 프론트엔드, 백엔드, 도구, 문서, 배포 등 둘 이상의 도메인을 동시에 수정한다.
- API, DB schema, protocol, DTO, 파일 포맷 같은 계약 변경이 포함된다.
- 구현, 테스트, 문서화가 한 PR에서 리뷰하기 어렵다.
- 작업 순서가 있거나 선행 계약 없이는 후속 구현이 불안정하다.
- 담당자나 검증 환경이 달라 병렬 작업 단위로 나누는 편이 안전하다.

하위 이슈 구성 순서:

1. 공통 계약 확정: API/인터페이스/DB/protocol/DTO/파일 포맷.
2. 기반 구현: 서버 서비스, 저장소, mock, generator 등 후속 작업이 의존하는 코드.
3. 독립 기능 구현: UI, 외부 연동, 도메인별 동작처럼 파일 충돌이 적은 단위.
4. 검증과 문서: E2E, 회귀 테스트, docs 갱신.

각 하위 이슈에는 독립적인 `작업 이유`, `목적`, `작업 계획`, `완료 기준`, `검증 계획`을 쓴다.
상위 이슈만 읽어도 전체 방향이 보이고, 하위 이슈만 읽어도 바로 작업할 수 있어야 한다.

## GitHub 조회 비용 관리

이슈 조회와 ProjectV2 확인은 GraphQL rate/cost 초과로 작업이 실패하지 않도록 다음 순서와 제한을 지킨다.

1. 직접 지정된 이슈가 있으면 direct lookup을 먼저 한다.
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
4. GraphQL은 ProjectV2와 관계 설정처럼 필요한 경우에만 쓴다.
   - REST/GitHub 앱/`gh issue`로 가능한 repo 정보, 템플릿/문서 확인, 중복 검색, 이슈 생성/수정, 본문/댓글, label, assignee, milestone 처리는 GraphQL로 대체하지 않는다.
   - `gh project field-list`는 비용이 크므로 status 확인용으로 사용하지 않는다.
   - ProjectV2 status 변경 전에는 item id, project id, status field id, option id를 한 번의 최소 query로 가져오고 같은 턴에서 재사용한다.
   - 저장소별 option id가 확인되어 있어도 실패하거나 Project schema가 바뀐 정황이 있으면 `projectV2.fields(first: 50)` query를 1회 실행한다.
   - Project fields 전체, Project item 전체, Project view 전체 조회는 기본 금지한다.
   - GraphQL은 touched issue만 대상으로 하고, 한 작업 묶음에서는 Project id, status field id, option id, issue node id 같은 안정 식별자를 1회 조회해 재사용한다.
   - 매번 schema introspection을 하지 않는다. `addSubIssue`와 `addBlockedBy`는 지원 mutation으로 간주하고, 실패 시에만 원인을 보고한다.
   - Relationship 조회/설정 쿼리 예시는 `references/github-query-policy.md`를 읽는다.
   - 관계 조회는 target issue와 직접 연결된 `parent`, `subIssues(first: 20)`, `blockedBy(first: 20)`, `blocking(first: 20)`, `projectItems(first: 20)`만 1-depth로 확인한다.
   - 관계 mutation 전에는 이미 같은 관계가 있는지 먼저 조회하고, 중복 mutation을 실행하지 않는다.
5. ProjectV2 검증은 최소 query로 한다.
   - 상태 변경 후 검증은 해당 issue의 `projectItems(first: 20)`와 `fieldValues(first: 20)`만 조회한다.
   - project fields 전체, project item 전체 목록, 모든 view item 조회를 반복하지 않는다.
6. GraphQL query를 새로 작성해야 하면 cost를 확인한다.
   - 비용이 커질 수 있는 query에는 가능하면 `rateLimit { cost remaining resetAt }`를 함께 요청한다.
   - remaining이 낮거나 실패가 반복되면 즉시 중단하고, 어떤 조회가 필요했는지와 사용자가 재시도할 수 있는 다음 조치를 보고한다.
7. GraphQL 조회는 병렬 실행하지 않는다.
   - 파일 읽기나 REST 성격의 작은 조회는 병렬화할 수 있지만, ProjectV2 GraphQL 조회/변경은 순차적으로 실행한다.

## 상태 판정

상태 결정 우선순위:

1. 이슈 본문 내용과 사용자 확인 필요 여부.
2. repo Project에 해당 상태 option이 실제 존재하는지.
3. 최근 유사 이슈의 field 관례.

기본값:

- 질문이 없고 구현자가 바로 착수 가능한 이슈는 `Todo`.
- 신규 등록 또는 실질 갱신 대상에 사용자 판단이 필요한 질문이 있거나 계약/범위/완료 기준이 불명확하면 GitHub 변경을 중단하고 다음 질문 하나를 제시한다.
- `Issue Review`는 이미 존재하는 이슈에서 새 모호성이 발견되어 범위 확정 없이 review 대기 표시만 하는 관리성 변경에 한정한다.
- 열린 blocker가 있어도 이슈 내용이 명확하면 `Todo`로 둔다. 단, `In Progress` 전환 후보에서는 제외한다.
- `Backlog`는 사용자 지시나 repo 문서로 `Todo` 동등 상태임이 확인된 경우에만 사용할 수 있다.

작업 대기 상태로 설정할 수 있는 조건:

- 목적과 완료 기준이 검증 가능한 문장으로 정리되어 있다.
- 구현 범위와 non-scope가 명확하다.
- API/인터페이스/데이터 계약이 확정되어 있다.
- 중복 또는 동일 문제 이슈가 canonical issue로 통합되어 있고, 남은 related/child 관계가 명확하다.
- UI 레이아웃 변경이 있으면 예상 레이아웃이 본문에 포함되어 있다.
- 저장소 관례에 맞는 assignee, Project, milestone, label 설정 여부가 확인되어 있다.
- 사용자의 추가 판단 없이 구현자가 바로 작업을 시작할 수 있다.

이미 존재하는 이슈를 리뷰 대기 상태로 설정해야 하는 조건:

- 요구사항의 목적이나 성공 기준이 여러 방향으로 해석될 수 있다.
- API, UI 흐름, 데이터 보존 범위, 성능 기준, 호환성 정책이 불확실하다.
- 작업 계획이 확정되지 않았거나 선행 결정 없이 구현하면 재작업 가능성이 크다.
- 저장소 관례상 필요한 assignee, Project, milestone 중 하나를 신뢰할 수 있게 설정하지 못했다.
- 작업 대기 상태 이슈에서 사용자 확인이 필요한 새 조건이 발견됐다.

신규 등록이나 실질 갱신에서는 위 조건을 `Issue Review` 생성 사유로 쓰지 말고, 등록 전 질문 gate의 미통과 사유로 보고한다.

## GitHub 처리 규칙

- 이슈 생성 전 기존 open/closed 이슈를 검색해 중복, 재오픈, 신규 등록 중 무엇이 맞는지 판단하되, `GitHub 조회 비용 관리`의 search limit과 후보 선별 순서를 지킨다.
- 신규 등록 또는 실질 갱신 전에는 등록 전 의도 확인 gate를 통과한다. 질문이 남아 있으면 이슈 생성, 본문 갱신, scope 변경, 하위 이슈 생성, relationship mutation을 실행하지 않는다.
- 중복 또는 동일 문제 이슈를 발견하면 canonical issue 본문에 통합 요구사항과 관련 이슈 목록을 추가한다.
- duplicate로 닫는 이슈에는 canonical issue 링크와 닫는 이유를 코멘트로 남긴다.
- 동일 문제이지만 독립 완료 기준이 남는 이슈는 닫지 말고 related/child 관계로 본문에 명시한다.
- 이슈 본문보다 최근 코멘트가 더 구체적이면 코멘트를 기준으로 본문을 갱신한다.
- GitHub 앱 도구로 가능한 작업은 앱 도구를 사용하고, ProjectV2 field나 Relationships처럼 앱 도구가 부족한 부분만 `gh` CLI 또는 GraphQL을 사용한다.
- GitHub connector에 relationship 전용 도구가 없는 상황은 fallback 사유가 아니다. `gh api graphql`의 `addSubIssue`와 `addBlockedBy`를 먼저 사용하고, mutation 실패 시에만 본문 fallback을 적용한다.
- ProjectV2 상태 변경 후에는 issue-level project item만 최소 GraphQL query로 다시 확인한다. project view 전체 조회는 사용자가 명시적으로 요구하거나 issue-level 검증이 실패한 경우에만 수행한다.
- Milestone과 assignee는 유사 이슈나 사용자의 명시 지시를 우선한다. 추론 근거가 약하면 등록 전에 질문으로 해소한다.

## 완료 전 자체 체크

- 새 이슈 생성 또는 실질 갱신 대상에 남은 질문이 없는가?
- `Issue Review`를 사용했다면 이미 존재하는 이슈의 관리성 review 대기 표시인가?
- 모든 생성/갱신 이슈의 상태가 등록 전 의도 확인 gate 결과와 일치하는가?
- 각 이슈의 `expectedStatus`와 실제 Project 상태가 일치하는가?
- 기대한 native parent/sub-issue 관계가 실제로 설정됐는가?
- 기대한 native blocked-by 관계가 실제로 설정됐는가?
- 본문 `Related`로 둔 관계가 순서 제약 없는 참고 관계가 맞는가?
- GraphQL fallback을 적용했다면 `gh api graphql` 실패 사유를 보고에 포함했는가?
- 비용 절감을 위해 생략한 Project fields/items/views 전체 조회가 실제로 불필요했는가?

## 보고 형식

작업 완료 보고에는 다음을 포함한다.

- 생성/갱신한 이슈 번호와 제목
- 각 이슈의 Project 상태, assignee, milestone, label
- 각 이슈의 `expectedStatus`와 `actualStatus`
- 하위 이슈와 blocking 관계
- native parent/sub-issue 설정 여부
- native blocked-by 설정 여부
- fallback이 있었다면 GraphQL 실패 사유
- 비용 절감을 위해 생략한 조회 범위와 판단 근거
- GitHub 변경을 중단했다면 다음 질문 하나와 추천 답변
- 사용자 확인 필요 질문 유무와 등록 전 gate 통과 여부
- 설정하지 못한 GitHub 필드가 있다면 실패 이유와 다음 조치
