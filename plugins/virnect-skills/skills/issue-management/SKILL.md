---
name: issue-management
description: "요구사항을 GitHub 이슈로 등록하거나 기존 이슈를 갱신하는 이슈 등록의 기본 진입점. 사용자는 단일 repo인지 multi repo인지 판단하지 않고 이 스킬로 이슈 등록을 요청한다. 여러 요구사항을 한 번에 받으면 요구사항 group으로 나누고, 각 group을 단일 issue, 같은 repo parent/sub-issue, product hub issue와 repo별 child issue로 자동 분류한다. 중복 이슈 통합, blocked-by 관계, ProjectV2 상태/Size/Estimate, milestone, assignees, labels, 작업 이유·목적·계획·완료 기준·검증 계획을 정리해야 할 때 사용한다. 이슈 등록 단계에서는 branch/worktree/PR/package override 실행을 하지 않는다."
---

# Issue Management

요구사항을 바로 작업 가능한 GitHub 이슈로 정리하고, 생성/갱신 전에 개발 의도와 필수 GitHub 메타데이터를 확정한다.
사용자가 단일 repo인지 multi repo인지 구분하지 않아도 이 Skill이 요구사항 group과 issue 구조를 결정한다.
이슈 생성, 갱신, 하위 이슈 분리, Project 상태/필드 변경, relationship 설정을 하나의 흐름으로 처리한다.

## Reference 로드 기준

- 이슈 본문을 작성하거나 갱신할 때는 `references/issue-body-template.md`를 읽는다.
- 관계, 하위 이슈 분리, blocked-by, 충돌 위험 판단이 애매하면 `references/relationship-policy.md`를 읽는다.
- GitHub 검색 제한, ProjectV2 Status/Size/Estimate, GraphQL 조회/변경/검증이 필요하면 `references/github-query-policy.md`를 읽는다.
- 관계/충돌 preflight가 필요하면 `scripts/gh-issue-preflight.ps1`를 우선 사용한다.
- product repo-local `.codex/multi-repo-issue-orchestration/profiles/*.json`, 로컬 Codex profile, 또는 명시된 multi-repo profile이 발견되면 product-only 판단 전에 profile과 sibling Skill `multi-repo-issue-orchestration`의 `references/profile-schema.md`를 먼저 읽는다.
- product/module repository 영향, product hub issue, repo별 child issue, product local package override 설정 계획이 필요하면 sibling Skill인 `multi-repo-issue-orchestration`을 helper로 읽는다.

## 핵심 원칙

- 이 Skill은 이슈 등록의 public front door다. 사용자가 single-repo/multi-repo를 먼저 고르게 하지 않는다.
- 여러 요구사항이 한 번에 들어오면 먼저 독립 목적, 완료 기준, 검증 경로, repository 영향별로 requirement group을 나눈다.
- 각 group은 product-only 단일 issue, 같은 repo parent/sub-issue, multi-repo product hub issue + repo별 child issue 중 하나로 분류한다.
- 사용자에게 보이는 이슈 제목, 본문, 코멘트, 보고는 저장소 지침과 현재 대화 언어에 맞춘다.
- 이슈 본문에는 `작업 이유`, `목적`, `작업 계획`, `완료 기준`, `검증 계획`을 포함한다.
- 새 이슈 생성 또는 본문·범위·계획을 바꾸는 실질 갱신 전에는 작업 이유, 목적/성공 기준, scope/non-scope, API/UI/data contract, 우선순위, 완료 기준, 검증 계획, 관계/의존성, 필수 GitHub 메타데이터를 모두 확정한다.
- 이슈 등록 단계에서는 branch 생성, worktree 생성, PR 생성, product local package override command 실행을 하지 않는다.
- 같은 요구사항의 이슈가 이미 있거나 같은 root cause와 같은 작업 범위로 해결되면 canonical issue로 통합한다.
- 사실, 추론, 사용자 확인 필요 사항을 섞지 않는다. 확실하지 않은 내용은 질문으로 분리하고, 답이 해소되기 전에는 새 이슈 생성이나 실질 갱신을 하지 않는다.
- 새 이슈와 하위 이슈를 생성하거나 work-ready 상태로 실질 갱신할 때는 Assignees, Project 상태, Project `Size`, Project `Estimate`를 필수로 설정한다.
- pure comment, duplicate close, 기존 이슈의 관리성 review 표시처럼 새 작업 단위를 등록하지 않는 변경에는 Assignees/Size/Estimate를 새로 강제하지 않는다.
- 기본 assignee는 이슈 등록을 지시한 사람의 GitHub login이다. 명시 계정이 없으면 현재 인증된 `gh` 또는 GitHub 앱 계정을 기본값으로 삼고, 확인할 수 없으면 등록 전에 질문한다.
- `Estimate`는 시간 단위 양의 정수다. 1시간 미만은 1시간으로 올림하고, 단일 생성 이슈의 `Estimate`는 18시간을 넘기지 않는다.
- 예상 작업이 18시간을 넘으면 더 작은 작업 단위로 나누어 이슈를 등록한다. 각 생성 이슈는 독립 완료 기준과 `Estimate <= 18`을 가져야 한다.
- `Size`는 Project field의 실제 타입/옵션과 최근 유사 이슈 관례로 결정한다. 신뢰할 수 없으면 값을 지어내지 말고 등록 전에 질문한다.
- `Backlog`는 금지 기본값이다. 사용자 지시나 repo 문서로 `Todo`의 동등 상태임이 확인된 경우에만 사용한다.

## 질문 지침

- 계획의 모든 측면에 대해 사용자와 공유된 이해에 도달할 때까지 질문한다.
- 설계 결정 트리의 각 분기를 따라가며 의존 관계가 있는 결정을 하나씩 해소한다.
- 질문은 한 번에 하나만 한다.
- 각 질문에는 사용자가 선택하거나 수정할 수 있는 추천 답변을 함께 제시한다.
- 질문 카드 도구가 제공되는 환경에서는 `request_user_input`으로 현재 가장 중요한 질문 하나만 묻는다. 필수 메타데이터 누락도 같은 질문 gate로 해소한다.
- 코드베이스 탐색으로 답할 수 있는 질문은 사용자에게 묻지 말고 먼저 코드, 문서, 기존 이슈, 설정을 확인한다.
- 사용자의 답변을 받은 뒤에는 그 결정이 하위 이슈 분리, relationship, 완료 기준, 검증 계획, Project 필드에 미치는 영향을 다시 점검한다.

## 저장소 설정 확인

이 스킬은 저장소별 기본값을 하드코딩하지 않는다. 매번 현재 repo에서 다음을 확인한다.

1. 저장소와 기본 브랜치:
   - `gh repo view --json nameWithOwner,defaultBranchRef`
2. 이슈/PR 작성 규칙:
   - `AGENTS.md`, `.github/ISSUE_TEMPLATE*`, `.github/PULL_REQUEST_TEMPLATE*`, `README*`
3. 최근 유사 이슈의 필드 관례:
   - `gh issue list --state open --limit 10 --json number,title,labels,assignees,milestone,projectItems`
   - 최근 유사 이슈의 status, Size, Estimate는 참고값이며, 이슈 본문 내용과 사용자 확인 필요 여부로 판정한 사전 계획을 덮어쓰지 않는다.
4. ProjectV2 상태명과 필수 field:
   - Status, Size, Estimate field 이름, 타입, option id, field id는 mutation 직전 최소 GraphQL query로 확인한다.
   - `Size`는 single-select일 수도 있고, 저장소별 다른 이름이나 옵션을 쓸 수 있다.
   - `Estimate`는 시간 단위 숫자 field를 기본으로 보되, 실제 field 타입과 이름을 확인한다.
5. assignees, milestone, Size, Estimate:
   - assignees는 이슈 등록 지시자의 GitHub login을 우선하고, 확인할 수 없으면 현재 인증 계정과 repo 문서, 최근 유사 이슈를 순서대로 확인한다.
   - milestone, Size, Estimate는 사용자의 명시 지시, repo 문서, 최근 유사 이슈를 우선한다.

## 생성 전 Hard Gate

새 이슈 생성 또는 본문·범위·계획의 실질 갱신 대상은 아래 gate를 모두 통과해야 한다.
하나라도 통과하지 못하면 GitHub 생성/갱신, Project field mutation, relationship mutation을 실행하지 않는다.

`statusPlan` 필수 항목:

- `group`: 여러 요구사항 입력에서 이 이슈가 속한 requirement group 이름 또는 식별자.
- `title`: 생성 또는 갱신할 이슈 제목.
- `reason`: 이 이슈를 생성/갱신하는 이유와 근거.
- `remainingQuestions`: 등록 전에 남은 사용자 확인 질문 목록. 신규 등록 또는 실질 갱신에서는 빈 목록이어야 한다. 단, 신규 원인 소유권 검토 `Issue Review` 이슈는 root-cause ownership 해소 질문만 남길 수 있다.
- `expectedStatus`: `Todo`, `Issue Review`, `Backlog` 같은 목표 Project 상태. `Backlog`는 명시 근거가 있을 때만 허용한다.
- `statusReason`: 해당 상태를 선택한 이유.
- `relationshipPlan`: parent/sub-issue, blocked-by, related 또는 관계 없음 판단.

`metadataPlan` 필수 항목:

- `assignees`: 이슈에 지정할 GitHub login 목록. 기본값은 이슈 등록을 지시한 사람이다.
- `project`: 이슈를 넣을 Project와 Project item 생성/갱신 방식.
- `status`: Project 상태 field 목표값. 보통 `Todo` 또는 동등 상태다.
- `size`: Project `Size` field 목표값. 실제 field 타입과 option을 확인한 값이어야 한다.
- `estimateHours`: Project `Estimate` field 목표값. 시간 단위 양의 정수이며 `1..18` 범위여야 한다.
- `splitRequired`: 예상 작업이 18시간을 넘어 하위 이슈 분리가 필요한지 여부.
- `metadataQuestions`: 등록 전에 남은 메타데이터 확인 질문 목록. 신규 등록 또는 실질 갱신에서는 빈 목록이어야 한다.

`rootCauseOwnershipPlan` 필수 항목:

- `symptomRepo`: 증상이 관측된 product 또는 module repository.
- `candidateRootCauseRepos`: profile, package, 코드 검색, 기존 이슈/PR로 확인한 root-cause 후보 repository 목록.
- `searchedSignals`: Jira key, 핵심 class/symbol/path/package명, package manifest/lock, ownership 문서처럼 실제 검색한 signal 목록.
- `activePrOrIssueCandidates`: 같은 root cause, package, 경로, PR 범위와 겹치는 open issue/PR 후보 목록.
- `ownershipDecision`: `product-only | module-root-cause | multi-repo | unresolved`.
- `decisionReason`: 해당 소유권 결정을 선택한 근거.

Hard stop 조건:

- `statusPlan`, `metadataPlan`, `rootCauseOwnershipPlan` 중 하나가 없거나 필수 항목이 누락됐다.
- `metadataQuestions`가 비어 있지 않다.
- `remainingQuestions`가 비어 있지 않다. 단, `ownershipDecision=unresolved`이고 `expectedStatus=Issue Review`인 원인 소유권 검토 이슈는 `remainingQuestions`가 root-cause ownership 해소 질문만 담을 수 있다.
- 구현 이슈의 목적, 완료 기준, API/인터페이스/데이터 계약, 구현 범위, non-scope가 불명확하다.
- Assignees, Project Status, Size, Estimate 중 하나를 신뢰할 수 있게 설정하지 못했다.
- `estimateHours > 18`인데 더 작은 작업 단위로 나누지 않았다.
- 신규 등록 또는 실질 갱신을 `Issue Review`로 만들려 한다. 단, `ownershipDecision=unresolved`인 신규 원인 소유권 검토 이슈는 허용한다.

작업 대기 상태로 둘 수 있는 조건:

- 목적과 완료 기준이 검증 가능한 문장으로 정리되어 있다.
- 구현 범위, non-scope, API/인터페이스/데이터 계약이 확정되어 있다.
- 중복 또는 동일 문제 이슈가 canonical issue로 통합되어 있고, 남은 related/child 관계가 명확하다.
- 저장소 관례에 맞는 assignees, Project 상태, Size, Estimate, milestone, label 설정 여부가 확인되어 있다.
- 각 생성 이슈의 `Estimate`가 18시간 이하이며, 초과 작업은 더 작은 이슈로 분리되어 있다.
- 사용자의 추가 판단 없이 구현자가 바로 작업을 시작할 수 있다.

`Issue Review`는 이미 존재하는 이슈에서 새 모호성이 발견되어 범위 확정 없이 review 대기 표시만 하는 관리성 변경에 한정한다. 예외적으로 신규 원인 소유권 검토 이슈는 `rootCauseOwnershipPlan.ownershipDecision=unresolved`이고 본문이 구현-ready처럼 보이지 않을 때만 생성할 수 있다.

## Workflow

1. 요구사항과 최신 근거를 모은다.
   - 지정된 이슈/PR/코멘트가 있으면 direct lookup을 먼저 한다.
   - 관련 코드, 문서, 기존 이슈를 확인해 중복 이슈와 이미 결정된 계약을 찾는다.
   - 중복 검색과 GraphQL 사용 제한은 `references/github-query-policy.md`를 따른다.
   - Root Cause Ownership Gate를 먼저 수행한다.
   - product repo-local `.codex/multi-repo-issue-orchestration/profiles/*.json`, 로컬 Codex profile, 또는 명시 profile이 있으면 profile과 `profile-schema.md`를 읽고 product/module repository 목록을 확정한다.
   - Jira key, 핵심 class/symbol/path/package명으로 symptom repo와 profile repos의 open issue/PR을 검색한다.
   - Unity repo에서는 profile `sourceRoot` 기준으로 `Packages/manifest.json`, `Packages/packages-lock.json`, package ownership 문서를 확인한다.
   - module/package root-cause가 plausible하면 product-only Todo 이슈 생성을 금지하고 `module-root-cause`, `multi-repo`, 또는 `unresolved`로 분류한다.
   - profile이 없으면 profile 부재를 `rootCauseOwnershipPlan.searchedSignals`와 `decisionReason`에 남기고, 확정 불가한 module 후보를 추측하지 않는다.
2. 등록 전 의도 확인 gate를 통과한다.
   - 코드베이스나 기존 이슈에서 확인 가능한 사실을 먼저 확인한다.
   - 제품 의도나 구현 방향이 여러 갈래로 남으면 한 번에 하나씩 질문한다.
3. 요구사항 group을 결정한다.
   - 서로 다른 목적, 완료 기준, 검증 경로, repository 영향, 배포/리뷰 단위는 별도 group으로 나눈다.
   - 같은 root cause, 데이터 계약, UI 흐름, PR 범위면 같은 group으로 묶는다.
   - 한 번의 사용자 입력에서 group이 여러 개면 issue 또는 hub issue도 여러 개가 될 수 있다.
4. 각 group의 이슈 구조를 결정한다.
   - 같은 root cause, 데이터 계약, UI 흐름, PR 범위면 canonical issue로 묶는다.
   - 독립 완료 기준이 있거나 단일 이슈 `Estimate`가 18시간을 넘으면 parent/sub-issue로 나눈다.
   - product-only이고 작은 작업이면 단일 product issue로 둔다.
   - product와 module/package repo가 함께 필요하거나 공통 계약 변경이 있으면 product hub issue와 repo별 child issue로 나눈다.
   - 관계와 분해 기준은 `references/relationship-policy.md`를 따른다.
5. `statusPlan`, `metadataPlan`, `rootCauseOwnershipPlan`, `expectedNativeRelations`를 작성한다.
   - 이 단계는 GitHub 이슈 생성/갱신과 GraphQL mutation 전에 완료한다.
   - `estimateHours > 18`이면 `splitRequired=true`로 두고 이슈 구조 결정으로 돌아간다.
   - 여러 group이면 group별로 작성하고, hub issue와 child issue 각각에 별도 계획을 둔다.
6. 이슈 본문을 작성한다.
   - `references/issue-body-template.md`를 사용한다.
   - 신규 등록 또는 실질 갱신 본문에는 `사용자 확인 필요 사항` 섹션을 남기지 않는다. 단, 신규 원인 소유권 검토 `Issue Review` 이슈는 root-cause ownership 해소 질문만 남길 수 있다.
7. GitHub 이슈를 생성하거나 갱신한다.
   - 저장소 관례와 `metadataPlan`에 맞는 assignees, Project Status, Size, Estimate, milestone, label을 설정한다.
   - parent/sub-issue와 blocked-by 관계는 GraphQL mutation을 먼저 시도한다.
   - 이 단계에서 branch/worktree/PR/package override 실행은 하지 않는다.
8. Project 상태와 필수 메타데이터를 검증한다.
   - touched issue만 대상으로 최소 GraphQL query를 실행한다.
   - `expectedStatus`, Project Size, Project Estimate가 계획과 일치하는지 확인한다.
   - 실제 assignees가 `metadataPlan.assignees`와 일치하는지 issue snapshot으로 확인한다.
   - `gh project item-add` 또는 `gh project item-edit` 출력만으로 완료 판정하지 않는다.
9. native relationship을 검증한다.
   - expected parent/sub-issue, blocked-by, blocking 관계와 실제 1-depth relationship이 일치하는지 확인한다.
10. 결과를 보고한다.
   - 생성/갱신 이슈, group별 분류, 상태, Project 필드, 관계, 검증 결과, fallback, 생략한 조회 범위와 판단 근거를 요약한다.
   - 이슈 등록만 완료했고 작업 실행은 하지 않았음을 명시한다.

## GitHub 처리 규칙

- GitHub 앱 도구로 가능한 작업은 앱 도구를 사용하고, ProjectV2 field나 Relationships처럼 앱 도구가 부족한 부분만 `gh` CLI 또는 GraphQL을 사용한다.
- GitHub connector에 relationship 전용 도구가 없는 상황은 fallback 사유가 아니다. `gh api graphql`의 `addSubIssue`와 `addBlockedBy`를 먼저 사용하고, mutation 실패 시에만 본문 fallback을 적용한다.
- Project 자동화나 기본값 때문에 `actualStatus=Backlog`가 되면 `Backlog` 허용 근거가 없는 한 `expectedStatus`로 즉시 보정하고 재검증한다.
- 보정 후에도 `statusPlan`/`metadataPlan`과 실제 값이 다르면 완료로 보고하지 말고 불일치와 실패 명령을 보고한다.
- 비용 절감을 위해 GraphQL은 순차 실행하고, project fields/items/views 전체 조회는 reference 정책에서 허용한 경우에만 수행한다.

## 완료 전 자체 체크

- 새 구현 이슈 생성 또는 실질 갱신 대상에 남은 질문이 없는가?
- 각 생성/갱신 대상 이슈에 `statusPlan`, `metadataPlan`, `rootCauseOwnershipPlan`이 있으며 필수 항목이 모두 명시됐는가?
- 신규 등록 또는 실질 갱신 대상의 `remainingQuestions`, `metadataQuestions`가 빈 목록인가? 원인 소유권 검토 `Issue Review`라면 남은 질문이 root-cause ownership에만 한정됐는가?
- 각 생성 이슈의 `Estimate`가 18시간 이하인가?
- `Issue Review`를 사용했다면 이미 존재하는 이슈의 관리성 review 대기 표시이거나 신규 원인 소유권 검토 이슈인가?
- multi-repo profile이 있는데도 product-only 단일 이슈로 뭉개지 않았는가?
- `Backlog`를 사용했다면 사용자 지시나 repo 문서로 `Todo` 동등 상태임이 확인됐는가?
- 각 이슈의 실제 Status, Assignees, Size, Estimate가 사전 계획과 일치하는가?
- 기대한 native parent/sub-issue와 blocked-by 관계가 실제로 설정됐는가?
- GraphQL fallback을 적용했다면 실패 사유를 보고에 포함했는가?
- 이슈 등록 요청에서 branch/worktree/PR/package override 실행을 하지 않았는가?

## 보고 형식

작업 완료 보고에는 다음을 포함한다.

- requirement group별 분류와 단일 issue/parent-sub/hub-sub 판단 근거
- 생성/갱신한 이슈 번호와 제목
- 각 이슈의 Project 상태, assignees, Size, Estimate, milestone, label
- 각 이슈의 `statusPlan`, `metadataPlan`, `rootCauseOwnershipPlan`, `expectedStatus`, `actualStatus`
- 하위 이슈와 blocking 관계, native relationship 설정 여부
- fallback이 있었다면 GraphQL 실패 사유
- 비용 절감을 위해 생략한 조회 범위와 판단 근거
- 등록 단계에서 작업 실행을 하지 않았다는 확인
- GitHub 변경을 중단했다면 다음 질문 하나와 추천 답변
