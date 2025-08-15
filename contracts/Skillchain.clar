(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_SKILL_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_ENDORSED (err u102))
(define-constant ERR_INSUFFICIENT_TOKENS (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_SELF_ENDORSEMENT (err u105))
(define-constant ERR_USER_NOT_FOUND (err u106))
(define-constant ERR_CHALLENGE_NOT_FOUND (err u107))
(define-constant ERR_CHALLENGE_EXPIRED (err u108))
(define-constant ERR_CHALLENGE_ALREADY_SUBMITTED (err u109))
(define-constant ERR_CHALLENGE_NOT_SUBMITTED (err u110))
(define-constant ERR_INSUFFICIENT_VERIFICATIONS (err u111))
(define-constant ERR_ALREADY_VERIFIED (err u112))
(define-constant ERR_INVALID_CHALLENGE_DURATION (err u113))
(define-constant ERR_CHALLENGE_ALREADY_COMPLETED (err u114))
(define-constant ERR_MENTORSHIP_NOT_FOUND (err u115))
(define-constant ERR_NOT_QUALIFIED_MENTOR (err u116))
(define-constant ERR_ALREADY_ENROLLED (err u117))
(define-constant ERR_NOT_ENROLLED (err u118))
(define-constant ERR_MODULE_NOT_FOUND (err u119))
(define-constant ERR_MODULE_NOT_COMPLETED (err u120))
(define-constant ERR_PROGRAM_COMPLETED (err u121))
(define-constant ERR_INSUFFICIENT_PROGRESS (err u122))

(define-fungible-token skill-token)

(define-data-var token-name (string-ascii 32) "SkillToken")
(define-data-var token-symbol (string-ascii 10) "SKILL")
(define-data-var token-decimals uint u6)
(define-data-var next-skill-id uint u1)
(define-data-var next-challenge-id uint u1)
(define-data-var next-mentorship-id uint u1)

(define-map users principal {
    reputation-score: uint,
    total-endorsements-given: uint,
    total-endorsements-received: uint,
    skills-count: uint
})

(define-map skills uint {
    owner: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),
    category: (string-ascii 30),
    endorsement-count: uint,
    total-tokens-staked: uint,
    created-at: uint
})

(define-map endorsements {skill-id: uint, endorser: principal} {
    tokens-staked: uint,
    message: (string-ascii 100),
    timestamp: uint
})

(define-map skill-categories (string-ascii 30) uint)

(define-map challenges uint {
    creator: principal,
    skill-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    difficulty: uint,
    reward-pool: uint,
    entry-fee: uint,
    duration-blocks: uint,
    created-at: uint,
    expires-at: uint,
    min-verifications: uint,
    status: (string-ascii 20)
})

(define-map challenge-submissions {challenge-id: uint, participant: principal} {
    submission-data: (string-ascii 500),
    submitted-at: uint,
    verification-count: uint,
    verification-score: uint,
    status: (string-ascii 20)
})

(define-map challenge-verifications {challenge-id: uint, participant: principal, verifier: principal} {
    score: uint,
    feedback: (string-ascii 200),
    verified-at: uint
})

(define-map challenge-leaderboard {challenge-id: uint, rank: uint} {
    participant: principal,
    final-score: uint,
    reward-earned: uint
})

;; Mentorship program data structures
(define-map mentorship-programs uint {
    mentor: principal,
    skill-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    total-modules: uint,
    program-fee: uint,
    mentor-share: uint,
    duration-weeks: uint,
    created-at: uint,
    active: bool,
    total-students: uint,
    completion-rate: uint
})

(define-map mentorship-modules {program-id: uint, module-number: uint} {
    title: (string-ascii 80),
    content: (string-ascii 400),
    requirements: (string-ascii 200),
    estimated-hours: uint
})

(define-map student-enrollments {program-id: uint, student: principal} {
    enrolled-at: uint,
    current-module: uint,
    modules-completed: uint,
    total-progress: uint,
    status: (string-ascii 20),
    mentor-rating: uint,
    completion-timestamp: uint
})

(define-map module-completions {program-id: uint, student: principal, module-number: uint} {
    completed-at: uint,
    mentor-approved: bool,
    submission: (string-ascii 300),
    mentor-feedback: (string-ascii 200)
})

(define-map skill-certificates {student: principal, program-id: uint} {
    issued-at: uint,
    mentor: principal,
    skill-id: uint,
    final-score: uint,
    certificate-hash: (string-ascii 64)
})

(define-public (initialize)
    (begin
        (try! (ft-mint? skill-token u1000000 CONTRACT_OWNER))
        (ok true)
    )
)

(define-public (register-user)
    (let ((user tx-sender))
        (if (is-none (map-get? users user))
            (begin
                (map-set users user {
                    reputation-score: u0,
                    total-endorsements-given: u0,
                    total-endorsements-received: u0,
                    skills-count: u0
                })
                (try! (ft-mint? skill-token u100 user))
                (ok true)
            )
            (ok false)
        )
    )
)

(define-public (create-skill (name (string-ascii 50)) (description (string-ascii 200)) (category (string-ascii 30)))
    (let (
        (skill-id (var-get next-skill-id))
        (user tx-sender)
        (current-stacks-block-height stacks-block-height)
    )
        (asserts! (> (len name) u0) ERR_INVALID_AMOUNT)
        (try! (register-user))
        (map-set skills skill-id {
            owner: user,
            name: name,
            description: description,
            category: category,
            endorsement-count: u0,
            total-tokens-staked: u0,
            created-at: current-stacks-block-height
        })
        (map-set skill-categories category 
            (+ (default-to u0 (map-get? skill-categories category)) u1))
        (let ((user-data (unwrap! (map-get? users user) ERR_USER_NOT_FOUND)))
            (map-set users user (merge user-data {
                skills-count: (+ (get skills-count user-data) u1)
            }))
        )
        (var-set next-skill-id (+ skill-id u1))
        (ok skill-id)
    )
)

(define-public (endorse-skill (skill-id uint) (tokens-to-stake uint) (message (string-ascii 100)))
    (let (
        (endorser tx-sender)
        (skill-data (unwrap! (map-get? skills skill-id) ERR_SKILL_NOT_FOUND))
        (skill-owner (get owner skill-data))
        (endorsement-key {skill-id: skill-id, endorser: endorser})
    )
        (asserts! (not (is-eq endorser skill-owner)) ERR_SELF_ENDORSEMENT)
        (asserts! (> tokens-to-stake u0) ERR_INVALID_AMOUNT)
        (asserts! (>= (ft-get-balance skill-token endorser) tokens-to-stake) ERR_INSUFFICIENT_TOKENS)
        (asserts! (is-none (map-get? endorsements endorsement-key)) ERR_ALREADY_ENDORSED)
        
        (try! (register-user))
        (try! (ft-transfer? skill-token tokens-to-stake endorser (as-contract tx-sender)))
        
        (map-set endorsements endorsement-key {
            tokens-staked: tokens-to-stake,
            message: message,
            timestamp: stacks-block-height
        })
        
        (map-set skills skill-id (merge skill-data {
            endorsement-count: (+ (get endorsement-count skill-data) u1),
            total-tokens-staked: (+ (get total-tokens-staked skill-data) tokens-to-stake)
        }))
        
        (let (
            (endorser-data (unwrap! (map-get? users endorser) ERR_USER_NOT_FOUND))
            (owner-data (unwrap! (map-get? users skill-owner) ERR_USER_NOT_FOUND))
        )
            (map-set users endorser (merge endorser-data {
                total-endorsements-given: (+ (get total-endorsements-given endorser-data) u1),
                reputation-score: (+ (get reputation-score endorser-data) u1)
            }))
            (map-set users skill-owner (merge owner-data {
                total-endorsements-received: (+ (get total-endorsements-received owner-data) u1),
                reputation-score: (+ (get reputation-score owner-data) tokens-to-stake)
            }))
        )
        
        (ok true)
    )
)

(define-public (withdraw-endorsement (skill-id uint))
    (let (
        (endorser tx-sender)
        (endorsement-key {skill-id: skill-id, endorser: endorser})
        (endorsement-data (unwrap! (map-get? endorsements endorsement-key) ERR_SKILL_NOT_FOUND))
        (skill-data (unwrap! (map-get? skills skill-id) ERR_SKILL_NOT_FOUND))
        (tokens-to-return (get tokens-staked endorsement-data))
    )
        (map-delete endorsements endorsement-key)
        
        (map-set skills skill-id (merge skill-data {
            endorsement-count: (- (get endorsement-count skill-data) u1),
            total-tokens-staked: (- (get total-tokens-staked skill-data) tokens-to-return)
        }))
        
        (as-contract (try! (ft-transfer? skill-token tokens-to-return tx-sender endorser)))
        (ok tokens-to-return)
    )
)

(define-public (distribute-rewards (skill-id uint))
    (let (
        (skill-data (unwrap! (map-get? skills skill-id) ERR_SKILL_NOT_FOUND))
        (skill-owner (get owner skill-data))
        (total-staked (get total-tokens-staked skill-data))
        (reward-amount (/ total-staked u10))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> reward-amount u0) ERR_INVALID_AMOUNT)
        
        (try! (ft-mint? skill-token reward-amount skill-owner))
        (ok reward-amount)
    )
)

(define-read-only (get-skill (skill-id uint))
    (map-get? skills skill-id)
)

(define-read-only (get-user (user principal))
    (map-get? users user)
)

(define-read-only (get-endorsement (skill-id uint) (endorser principal))
    (map-get? endorsements {skill-id: skill-id, endorser: endorser})
)

(define-read-only (get-token-balance (user principal))
    (ft-get-balance skill-token user)
)

(define-read-only (get-total-supply)
    (ft-get-supply skill-token)
)

(define-read-only (get-category-count (category (string-ascii 30)))
    (default-to u0 (map-get? skill-categories category))
)

(define-read-only (get-next-skill-id)
    (var-get next-skill-id)
)

(define-read-only (get-token-info)
    {
        name: (var-get token-name),
        symbol: (var-get token-symbol),
        decimals: (var-get token-decimals)
    }
)

(define-read-only (calculate-reputation-score (user principal))
    (match (map-get? users user)
        user-data (+ 
            (get reputation-score user-data)
            (* (get total-endorsements-given user-data) u2)
            (* (get skills-count user-data) u5)
        )
        u0
    )
)

(define-read-only (get-skill-reputation (skill-id uint))
    (match (map-get? skills skill-id)
        skill-data {
            endorsement-count: (get endorsement-count skill-data),
            total-tokens-staked: (get total-tokens-staked skill-data),
            reputation-score: (+ 
                (* (get endorsement-count skill-data) u10)
                (get total-tokens-staked skill-data)
            )
        }
        {endorsement-count: u0, total-tokens-staked: u0, reputation-score: u0}
    )
)

(define-public (create-challenge (skill-id uint) (title (string-ascii 100)) (description (string-ascii 300)) (difficulty uint) (reward-pool uint) (entry-fee uint) (duration-blocks uint) (min-verifications uint))
    (let (
        (challenge-id (var-get next-challenge-id))
        (creator tx-sender)
        (current-block stacks-block-height)
        (expires-at (+ current-block duration-blocks))
    )
        (asserts! (is-some (map-get? skills skill-id)) ERR_SKILL_NOT_FOUND)
        (asserts! (> duration-blocks u0) ERR_INVALID_CHALLENGE_DURATION)
        (asserts! (> (len title) u0) ERR_INVALID_AMOUNT)
        (asserts! (> difficulty u0) ERR_INVALID_AMOUNT)
        (asserts! (<= difficulty u10) ERR_INVALID_AMOUNT)
        (asserts! (> reward-pool u0) ERR_INVALID_AMOUNT)
        (asserts! (>= (ft-get-balance skill-token creator) reward-pool) ERR_INSUFFICIENT_TOKENS)
        (asserts! (> min-verifications u0) ERR_INVALID_AMOUNT)
        (asserts! (<= min-verifications u10) ERR_INVALID_AMOUNT)
        
        (try! (ft-transfer? skill-token reward-pool creator (as-contract tx-sender)))
        
        (map-set challenges challenge-id {
            creator: creator,
            skill-id: skill-id,
            title: title,
            description: description,
            difficulty: difficulty,
            reward-pool: reward-pool,
            entry-fee: entry-fee,
            duration-blocks: duration-blocks,
            created-at: current-block,
            expires-at: expires-at,
            min-verifications: min-verifications,
            status: "active"
        })
        
        (var-set next-challenge-id (+ challenge-id u1))
        (ok challenge-id)
    )
)

(define-public (submit-to-challenge (challenge-id uint) (submission-data (string-ascii 500)))
    (let (
        (participant tx-sender)
        (challenge-data (unwrap! (map-get? challenges challenge-id) ERR_CHALLENGE_NOT_FOUND))
        (submission-key {challenge-id: challenge-id, participant: participant})
        (current-block stacks-block-height)
        (entry-fee (get entry-fee challenge-data))
    )
        (asserts! (< current-block (get expires-at challenge-data)) ERR_CHALLENGE_EXPIRED)
        (asserts! (is-eq (get status challenge-data) "active") ERR_CHALLENGE_ALREADY_COMPLETED)
        (asserts! (is-none (map-get? challenge-submissions submission-key)) ERR_CHALLENGE_ALREADY_SUBMITTED)
        (asserts! (> (len submission-data) u0) ERR_INVALID_AMOUNT)
        
        (if (> entry-fee u0)
            (begin
                (asserts! (>= (ft-get-balance skill-token participant) entry-fee) ERR_INSUFFICIENT_TOKENS)
                (try! (ft-transfer? skill-token entry-fee participant (as-contract tx-sender)))
            )
            true
        )
        
        (map-set challenge-submissions submission-key {
            submission-data: submission-data,
            submitted-at: current-block,
            verification-count: u0,
            verification-score: u0,
            status: "pending"
        })
        
        (ok true)
    )
)

(define-public (verify-submission (challenge-id uint) (participant principal) (score uint) (feedback (string-ascii 200)))
    (let (
        (verifier tx-sender)
        (challenge-data (unwrap! (map-get? challenges challenge-id) ERR_CHALLENGE_NOT_FOUND))
        (submission-key {challenge-id: challenge-id, participant: participant})
        (submission-data (unwrap! (map-get? challenge-submissions submission-key) ERR_CHALLENGE_NOT_SUBMITTED))
        (verification-key {challenge-id: challenge-id, participant: participant, verifier: verifier})
        (current-block stacks-block-height)
    )
        (asserts! (< current-block (get expires-at challenge-data)) ERR_CHALLENGE_EXPIRED)
        (asserts! (not (is-eq verifier participant)) ERR_SELF_ENDORSEMENT)
        (asserts! (is-none (map-get? challenge-verifications verification-key)) ERR_ALREADY_VERIFIED)
        (asserts! (> score u0) ERR_INVALID_AMOUNT)
        (asserts! (<= score u100) ERR_INVALID_AMOUNT)
        
        (map-set challenge-verifications verification-key {
            score: score,
            feedback: feedback,
            verified-at: current-block
        })
        
        (let (
            (new-verification-count (+ (get verification-count submission-data) u1))
            (new-verification-score (+ (get verification-score submission-data) score))
        )
            (map-set challenge-submissions submission-key (merge submission-data {
                verification-count: new-verification-count,
                verification-score: new-verification-score,
                status: (if (>= new-verification-count (get min-verifications challenge-data)) "verified" "pending")
            }))
        )
        
        (ok true)
    )
)

(define-public (finalize-challenge (challenge-id uint))
    (let (
        (challenge-data (unwrap! (map-get? challenges challenge-id) ERR_CHALLENGE_NOT_FOUND))
        (current-block stacks-block-height)
    )
        (asserts! (>= current-block (get expires-at challenge-data)) ERR_CHALLENGE_EXPIRED)
        (asserts! (is-eq (get status challenge-data) "active") ERR_CHALLENGE_ALREADY_COMPLETED)
        
        (map-set challenges challenge-id (merge challenge-data {
            status: "completed"
        }))
        
        (try! (distribute-challenge-rewards challenge-id))
        (ok true)
    )
)

(define-private (distribute-challenge-rewards (challenge-id uint))
    (let (
        (challenge-data (unwrap! (map-get? challenges challenge-id) ERR_CHALLENGE_NOT_FOUND))
        (reward-pool (get reward-pool challenge-data))
        (first-place-reward (/ (* reward-pool u50) u100))
        (second-place-reward (/ (* reward-pool u30) u100))
        (third-place-reward (/ (* reward-pool u20) u100))
    )
        (match (map-get? challenge-leaderboard {challenge-id: challenge-id, rank: u1})
            first-place-data 
            (begin
                (as-contract (try! (ft-transfer? skill-token first-place-reward tx-sender (get participant first-place-data))))
                (map-set challenge-leaderboard {challenge-id: challenge-id, rank: u1} 
                    (merge first-place-data {reward-earned: first-place-reward}))
            )
            true
        )
        
        (match (map-get? challenge-leaderboard {challenge-id: challenge-id, rank: u2})
            second-place-data 
            (begin
                (as-contract (try! (ft-transfer? skill-token second-place-reward tx-sender (get participant second-place-data))))
                (map-set challenge-leaderboard {challenge-id: challenge-id, rank: u2} 
                    (merge second-place-data {reward-earned: second-place-reward}))
            )
            true
        )
        
        (match (map-get? challenge-leaderboard {challenge-id: challenge-id, rank: u3})
            third-place-data 
            (begin
                (as-contract (try! (ft-transfer? skill-token third-place-reward tx-sender (get participant third-place-data))))
                (map-set challenge-leaderboard {challenge-id: challenge-id, rank: u3} 
                    (merge third-place-data {reward-earned: third-place-reward}))
            )
            true
        )
        
        (ok true)
    )
)

(define-public (update-leaderboard (challenge-id uint) (participant principal) (final-score uint) (rank uint))
    (let (
        (challenge-data (unwrap! (map-get? challenges challenge-id) ERR_CHALLENGE_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (<= rank u10) ERR_INVALID_AMOUNT)
        (asserts! (> final-score u0) ERR_INVALID_AMOUNT)
        
        (map-set challenge-leaderboard {challenge-id: challenge-id, rank: rank} {
            participant: participant,
            final-score: final-score,
            reward-earned: u0
        })
        
        (ok true)
    )
)

(define-read-only (get-challenge (challenge-id uint))
    (map-get? challenges challenge-id)
)

(define-read-only (get-challenge-submission (challenge-id uint) (participant principal))
    (map-get? challenge-submissions {challenge-id: challenge-id, participant: participant})
)

(define-read-only (get-challenge-verification (challenge-id uint) (participant principal) (verifier principal))
    (map-get? challenge-verifications {challenge-id: challenge-id, participant: participant, verifier: verifier})
)

(define-read-only (get-challenge-leaderboard (challenge-id uint) (rank uint))
    (map-get? challenge-leaderboard {challenge-id: challenge-id, rank: rank})
)

(define-read-only (get-next-challenge-id)
    (var-get next-challenge-id)
)

(define-read-only (is-challenge-active (challenge-id uint))
    (match (map-get? challenges challenge-id)
        challenge-data (and
            (< stacks-block-height (get expires-at challenge-data))
            (is-eq (get status challenge-data) "active")
        )
        false
    )
)

(define-read-only (calculate-average-score (challenge-id uint) (participant principal))
    (match (map-get? challenge-submissions {challenge-id: challenge-id, participant: participant})
        submission-data 
        (if (> (get verification-count submission-data) u0)
            (/ (get verification-score submission-data) (get verification-count submission-data))
            u0
        )
        u0
    )
)

;; Create a mentorship program for a specific skill
(define-public (create-mentorship-program (skill-id uint) (title (string-ascii 100)) (description (string-ascii 300)) (total-modules uint) (program-fee uint) (mentor-share uint) (duration-weeks uint))
    (let (
        (program-id (var-get next-mentorship-id))
        (mentor tx-sender)
        (skill-data (unwrap! (map-get? skills skill-id) ERR_SKILL_NOT_FOUND))
        (mentor-reputation (calculate-reputation-score mentor))
    )
        ;; Validate mentor qualification - must have high reputation and own the skill
        (asserts! (is-eq (get owner skill-data) mentor) ERR_NOT_QUALIFIED_MENTOR)
        (asserts! (>= mentor-reputation u50) ERR_NOT_QUALIFIED_MENTOR)
        (asserts! (> total-modules u0) ERR_INVALID_AMOUNT)
        (asserts! (<= total-modules u20) ERR_INVALID_AMOUNT)
        (asserts! (> duration-weeks u0) ERR_INVALID_AMOUNT)
        (asserts! (<= mentor-share u80) ERR_INVALID_AMOUNT)
        (asserts! (> (len title) u0) ERR_INVALID_AMOUNT)
        
        (map-set mentorship-programs program-id {
            mentor: mentor,
            skill-id: skill-id,
            title: title,
            description: description,
            total-modules: total-modules,
            program-fee: program-fee,
            mentor-share: mentor-share,
            duration-weeks: duration-weeks,
            created-at: stacks-block-height,
            active: true,
            total-students: u0,
            completion-rate: u0
        })
        
        (var-set next-mentorship-id (+ program-id u1))
        (ok program-id)
    )
)

;; Add learning modules to a mentorship program
(define-public (add-mentorship-module (program-id uint) (module-number uint) (title (string-ascii 80)) (content (string-ascii 400)) (requirements (string-ascii 200)) (estimated-hours uint))
    (let (
        (program-data (unwrap! (map-get? mentorship-programs program-id) ERR_MENTORSHIP_NOT_FOUND))
        (mentor (get mentor program-data))
    )
        (asserts! (is-eq tx-sender mentor) ERR_NOT_AUTHORIZED)
        (asserts! (<= module-number (get total-modules program-data)) ERR_INVALID_AMOUNT)
        (asserts! (> (len title) u0) ERR_INVALID_AMOUNT)
        (asserts! (> estimated-hours u0) ERR_INVALID_AMOUNT)
        
        (map-set mentorship-modules {program-id: program-id, module-number: module-number} {
            title: title,
            content: content,
            requirements: requirements,
            estimated-hours: estimated-hours
        })
        
        (ok true)
    )
)

;; Enroll student in mentorship program
(define-public (enroll-in-mentorship (program-id uint))
    (let (
        (student tx-sender)
        (program-data (unwrap! (map-get? mentorship-programs program-id) ERR_MENTORSHIP_NOT_FOUND))
        (enrollment-key {program-id: program-id, student: student})
        (program-fee (get program-fee program-data))
    )
        (asserts! (get active program-data) ERR_MENTORSHIP_NOT_FOUND)
        (asserts! (is-none (map-get? student-enrollments enrollment-key)) ERR_ALREADY_ENROLLED)
        (asserts! (>= (ft-get-balance skill-token student) program-fee) ERR_INSUFFICIENT_TOKENS)
        
        ;; Transfer program fee to contract
        (if (> program-fee u0)
            (try! (ft-transfer? skill-token program-fee student (as-contract tx-sender)))
            true
        )
        
        ;; Create enrollment record
        (map-set student-enrollments enrollment-key {
            enrolled-at: stacks-block-height,
            current-module: u1,
            modules-completed: u0,
            total-progress: u0,
            status: "active",
            mentor-rating: u0,
            completion-timestamp: u0
        })
        
        ;; Update program student count
        (map-set mentorship-programs program-id (merge program-data {
            total-students: (+ (get total-students program-data) u1)
        }))
        
        (ok true)
    )
)

;; Submit module completion for mentor review
(define-public (submit-module-completion (program-id uint) (module-number uint) (submission (string-ascii 300)))
    (let (
        (student tx-sender)
        (enrollment-key {program-id: program-id, student: student})
        (enrollment-data (unwrap! (map-get? student-enrollments enrollment-key) ERR_NOT_ENROLLED))
        (completion-key {program-id: program-id, student: student, module-number: module-number})
    )
        (asserts! (is-eq (get status enrollment-data) "active") ERR_PROGRAM_COMPLETED)
        (asserts! (is-eq (get current-module enrollment-data) module-number) ERR_MODULE_NOT_FOUND)
        (asserts! (is-some (map-get? mentorship-modules {program-id: program-id, module-number: module-number})) ERR_MODULE_NOT_FOUND)
        (asserts! (> (len submission) u0) ERR_INVALID_AMOUNT)
        
        (map-set module-completions completion-key {
            completed-at: stacks-block-height,
            mentor-approved: false,
            submission: submission,
            mentor-feedback: ""
        })
        
        (ok true)
    )
)

;; Mentor approves student module completion
(define-public (approve-module-completion (program-id uint) (student principal) (module-number uint) (feedback (string-ascii 200)))
    (let (
        (mentor tx-sender)
        (program-data (unwrap! (map-get? mentorship-programs program-id) ERR_MENTORSHIP_NOT_FOUND))
        (enrollment-key {program-id: program-id, student: student})
        (enrollment-data (unwrap! (map-get? student-enrollments enrollment-key) ERR_NOT_ENROLLED))
        (completion-key {program-id: program-id, student: student, module-number: module-number})
        (completion-data (unwrap! (map-get? module-completions completion-key) ERR_MODULE_NOT_FOUND))
    )
        (asserts! (is-eq mentor (get mentor program-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get mentor-approved completion-data)) ERR_MODULE_NOT_COMPLETED)
        
        ;; Mark module as approved
        (map-set module-completions completion-key (merge completion-data {
            mentor-approved: true,
            mentor-feedback: feedback
        }))
        
        ;; Update student progress
        (let (
            (new-modules-completed (+ (get modules-completed enrollment-data) u1))
            (new-current-module (+ module-number u1))
            (total-modules (get total-modules program-data))
            (new-progress (/ (* new-modules-completed u100) total-modules))
        )
            (map-set student-enrollments enrollment-key (merge enrollment-data {
                current-module: (if (<= new-current-module total-modules) new-current-module module-number),
                modules-completed: new-modules-completed,
                total-progress: new-progress,
                status: (if (is-eq new-modules-completed total-modules) "completed" "active")
            }))
            
            ;; Issue certificate if program completed
            (if (is-eq new-modules-completed total-modules)
                (try! (issue-skill-certificate program-id student))
                true
            )
            (ok true)
        )
    )
)

;; Issue skill certificate upon program completion
(define-private (issue-skill-certificate (program-id uint) (student principal))
    (let (
        (program-data (unwrap! (map-get? mentorship-programs program-id) ERR_MENTORSHIP_NOT_FOUND))
        (enrollment-data (unwrap! (map-get? student-enrollments {program-id: program-id, student: student}) ERR_NOT_ENROLLED))
        (certificate-key {student: student, program-id: program-id})
        (final-score (get total-progress enrollment-data))
        (mentor (get mentor program-data))
        (skill-id (get skill-id program-data))
    )
        (map-set skill-certificates certificate-key {
            issued-at: stacks-block-height,
            mentor: mentor,
            skill-id: skill-id,
            final-score: final-score,
            certificate-hash: "hash-placeholder"
        })
        
        ;; Update completion timestamp
        (map-set student-enrollments {program-id: program-id, student: student} (merge enrollment-data {
            completion-timestamp: stacks-block-height
        }))
        
        ;; Distribute payment to mentor
        (try! (distribute-mentorship-payment program-id))
        (ok true)
    )
)

;; Distribute payment between platform and mentor
(define-private (distribute-mentorship-payment (program-id uint))
    (let (
        (program-data (unwrap! (map-get? mentorship-programs program-id) ERR_MENTORSHIP_NOT_FOUND))
        (mentor (get mentor program-data))
        (program-fee (get program-fee program-data))
        (mentor-share-percent (get mentor-share program-data))
        (mentor-payment (/ (* program-fee mentor-share-percent) u100))
        (platform-fee (- program-fee mentor-payment))
    )
        ;; Pay mentor
        (as-contract (try! (ft-transfer? skill-token mentor-payment tx-sender mentor)))
        ;; Keep platform fee in contract
        (ok true)
    )
)

;; Read-only functions for mentorship system
(define-read-only (get-mentorship-program (program-id uint))
    (map-get? mentorship-programs program-id)
)

(define-read-only (get-mentorship-module (program-id uint) (module-number uint))
    (map-get? mentorship-modules {program-id: program-id, module-number: module-number})
)

(define-read-only (get-student-enrollment (program-id uint) (student principal))
    (map-get? student-enrollments {program-id: program-id, student: student})
)

(define-read-only (get-module-completion (program-id uint) (student principal) (module-number uint))
    (map-get? module-completions {program-id: program-id, student: student, module-number: module-number})
)

(define-read-only (get-skill-certificate (student principal) (program-id uint))
    (map-get? skill-certificates {student: student, program-id: program-id})
)

(define-read-only (get-next-mentorship-id)
    (var-get next-mentorship-id)
)

(define-read-only (calculate-program-completion-rate (program-id uint))
    (match (map-get? mentorship-programs program-id)
        program-data 
        (let (
            (total-students (get total-students program-data))
        )
            (if (> total-students u0)
                (/ (* (get completion-rate program-data) u100) total-students)
                u0
            )
        )
        u0
    )
)


