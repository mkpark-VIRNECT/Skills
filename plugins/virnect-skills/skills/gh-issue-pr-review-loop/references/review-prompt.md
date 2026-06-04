# 독립 리뷰 프롬프트

PR이 생성되고 로컬 검증 결과가 정리된 뒤 읽는다.
리뷰는 가능하면 서브에이전트나 독립 리뷰 도구에 위임하고, 없으면 별도 pass로 PR diff를 리뷰해 GitHub-visible 코멘트를 남긴다.

```text
PR <PR 번호>를 코드리뷰해 주세요.

- 저장소: <owner/repo>
- 기준 이슈: #<issue-number>
- PR URL: <url>
- Relationship/충돌 preflight: <blocked-by, parent/sub-issue, overlapping PR, 충돌 위험 파일 요약>
- 리뷰 코멘트는 GitHub PR에 <저장소/사용자 언어>로 남겨 주세요.
- 버그, 회귀, 계약 불일치, 누락된 테스트를 우선 검토해 주세요.
- 선행 이슈나 active PR과의 작업 순서, stale relationship, 파일군 충돌 가능성도 같이 검토해 주세요.
- 수정 요청이 있으면 파일/라인/재현 조건을 구체적으로 적어 주세요.
- 작성자 본인 PR이라 REQUEST_CHANGES가 거부되면 COMMENT review 또는 PR 코멘트로 남겨 주세요.
- 코드 수정은 하지 말고 리뷰 결과와 남긴 코멘트 URL만 보고해 주세요.
```

리뷰 후 다음을 확인한다.

- 리뷰어의 최종 보고
- PR review thread와 top-level PR comment
- GitHub에 실제 코멘트가 남았는지
