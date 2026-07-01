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
| 단일 이슈 예상 작업이 18시간을 넘음 | parent/sub-issue | 더 작은 작업 단위로 나누고 각 하위 이슈의 Estimate가 18시간 이하가 되게 한다. |
| API/DTO/DB/protocol/공통 컴포넌트가 먼저 확정돼야 함 | blocked-by | 후속 이슈가 선행 이슈에 의해 blocked 되도록 설정한다. |
| 같은 화면, 모델, service, repository, generated file, E2E fixture를 active PR이 수정 중임 | blocked-by 또는 conflict-risk | 후속 작업이 선행 PR merge를 기다려야 하면 blocked-by를 설정하고, 단순 충돌 위험이면 본문과 PR에 위험 파일을 기록한다. |
| product 증상이고 module/package root-cause가 확인됨 | module issue/PR canonical | 구현 소유권은 module issue/PR에 두고, product issue는 hub 또는 통합 검증 이슈가 필요할 때만 둔다. |
| product 검증이 module PR merge 또는 package publish를 기다림 | blocked-by | product issue가 module PR 또는 연결 issue에 의해 blocked 되도록 설정한다. |
| module/package root-cause가 plausible하지만 미확정 | related 또는 review | 구체 module PR/issue가 확인된 경우에만 blocked-by를 만들고, 후보 수준이면 Related와 원인 소유권 검토 본문에 근거를 남긴다. |
| 관련 문맥만 공유하고 작업 순서가 없음 | related | GitHub relationship mutation은 만들지 않고 본문 `Related`에만 남긴다. |

## Product 증상과 Module Root Cause

- product 이슈는 증상 추적, hub 조율, 통합 검증 책임이 있을 때만 둔다.
- module/package root-cause가 확인되면 구현 계획과 완료 기준은 module issue/PR에 둔다.
- active module PR이 있으면 새 module issue를 만들기 전에 기존 PR과 연결 issue를 canonical, related, blocker 후보로 확인한다.
- `unresolved` 상태에서는 product-only 구현 이슈를 만들지 말고 원인 소유권 검토 이슈나 질문으로 멈춘다.

## 하위 이슈 분리 기준

하위 이슈를 만들기 전에 먼저 동일 문제를 하나로 묶을 수 있는지 확인한다.
사용자의 요구가 문장상 분리되어 있어도 같은 root cause, 같은 API/DB/UI 계약, 같은 PR에서 해결해야 하는 변경이면 하위 이슈로 쪼개지 말고 canonical issue에 통합한다.

다음 중 하나라도 해당하면 하위 이슈 분리를 우선한다.

- 단일 이슈의 예상 작업 시간이 18시간을 넘는다.
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

각 하위 이슈에는 독립적인 `작업 이유`, `목적`, `작업 계획`, `완료 기준`, `검증 계획`과 `Estimate <= 18`을 둔다.
상위 이슈만 읽어도 전체 방향이 보이고, 하위 이슈만 읽어도 바로 작업할 수 있어야 한다.

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
