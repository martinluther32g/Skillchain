(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_SKILL_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_ENDORSED (err u102))
(define-constant ERR_INSUFFICIENT_TOKENS (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_SELF_ENDORSEMENT (err u105))
(define-constant ERR_USER_NOT_FOUND (err u106))

(define-fungible-token skill-token)

(define-data-var token-name (string-ascii 32) "SkillToken")
(define-data-var token-symbol (string-ascii 10) "SKILL")
(define-data-var token-decimals uint u6)
(define-data-var next-skill-id uint u1)

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