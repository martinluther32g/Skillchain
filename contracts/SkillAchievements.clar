;; SkillAchievements Contract
;; Gamified achievement system for skill development goals and milestones
;; Enhances user engagement through personal progression tracking

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_ACHIEVEMENT_NOT_FOUND (err u401))
(define-constant ERR_INVALID_GOAL (err u402))
(define-constant ERR_ALREADY_COMPLETED (err u403))
(define-constant ERR_GOAL_NOT_MET (err u404))
(define-constant ERR_INVALID_PROGRESS (err u405))

(define-data-var achievement-counter uint u0)

;; Achievement goal definitions
(define-map skill-achievements
  uint
  {
    creator: principal,
    title: (string-ascii 80),
    description: (string-ascii 200),
    skill-category: (string-ascii 30),
    target-type: (string-ascii 20),
    target-value: uint,
    reward-tokens: uint,
    created-at: uint,
    active: bool
  }
)

;; User progress towards achievements
(define-map user-achievement-progress
  { achievement-id: uint, user: principal }
  {
    current-progress: uint,
    progress-percentage: uint,
    started-at: uint,
    last-updated: uint,
    completed: bool,
    completed-at: (optional uint)
  }
)

;; Achievement completions and badges earned
(define-map earned-achievements
  { user: principal, achievement-id: uint }
  {
    completed-at: uint,
    final-progress: uint,
    badge-earned: bool,
    tokens-earned: uint
  }
)

;; User achievement statistics
(define-map user-achievement-stats
  { user: principal }
  {
    total-achievements: uint,
    completed-achievements: uint,
    completion-rate: uint,
    total-tokens-earned: uint,
    achievement-streak: uint,
    last-completion: uint
  }
)

;; Create a new skill achievement goal
(define-public (create-achievement (title (string-ascii 80)) (description (string-ascii 200)) (skill-category (string-ascii 30)) (target-type (string-ascii 20)) (target-value uint) (reward-tokens uint))
  (let (
    (achievement-id (+ (var-get achievement-counter) u1))
    (creator tx-sender)
  )
    ;; Validate inputs
    (asserts! (> (len title) u0) ERR_INVALID_GOAL)
    (asserts! (> target-value u0) ERR_INVALID_GOAL)
    (asserts! (or (is-eq target-type "endorsements") (is-eq target-type "reputation") (is-eq target-type "challenges") (is-eq target-type "mentorships")) ERR_INVALID_GOAL)
    
    (map-set skill-achievements achievement-id {
      creator: creator,
      title: title,
      description: description,
      skill-category: skill-category,
      target-type: target-type,
      target-value: target-value,
      reward-tokens: reward-tokens,
      created-at: stacks-block-height,
      active: true
    })
    
    (var-set achievement-counter achievement-id)
    (ok achievement-id)
  )
)

;; Start working towards an achievement
(define-public (start-achievement (achievement-id uint))
  (let (
    (user tx-sender)
    (achievement (unwrap! (map-get? skill-achievements achievement-id) ERR_ACHIEVEMENT_NOT_FOUND))
  )
    (asserts! (get active achievement) ERR_ACHIEVEMENT_NOT_FOUND)
    (asserts! (is-none (map-get? user-achievement-progress { achievement-id: achievement-id, user: user })) ERR_ALREADY_COMPLETED)
    
    (map-set user-achievement-progress { achievement-id: achievement-id, user: user } {
      current-progress: u0,
      progress-percentage: u0,
      started-at: stacks-block-height,
      last-updated: stacks-block-height,
      completed: false,
      completed-at: none
    })
    
    ;; Initialize user stats if needed
    (if (is-none (map-get? user-achievement-stats { user: user }))
      (map-set user-achievement-stats { user: user } {
        total-achievements: u1,
        completed-achievements: u0,
        completion-rate: u0,
        total-tokens-earned: u0,
        achievement-streak: u0,
        last-completion: u0
      })
      (let (
        (current-stats (unwrap! (map-get? user-achievement-stats { user: user }) ERR_UNAUTHORIZED))
      )
        (map-set user-achievement-stats { user: user } (merge current-stats {
          total-achievements: (+ (get total-achievements current-stats) u1)
        }))
      )
    )
    
    (ok true)
  )
)

;; Update progress towards an achievement
(define-public (update-achievement-progress (achievement-id uint) (new-progress uint))
  (let (
    (user tx-sender)
    (achievement (unwrap! (map-get? skill-achievements achievement-id) ERR_ACHIEVEMENT_NOT_FOUND))
    (progress-data (unwrap! (map-get? user-achievement-progress { achievement-id: achievement-id, user: user }) ERR_ACHIEVEMENT_NOT_FOUND))
    (target-value (get target-value achievement))
    (progress-percentage (/ (* new-progress u100) target-value))
  )
    (asserts! (not (get completed progress-data)) ERR_ALREADY_COMPLETED)
    (asserts! (>= new-progress (get current-progress progress-data)) ERR_INVALID_PROGRESS)
    
    ;; Update progress
    (map-set user-achievement-progress { achievement-id: achievement-id, user: user } (merge progress-data {
      current-progress: new-progress,
      progress-percentage: progress-percentage,
      last-updated: stacks-block-height,
      completed: (>= new-progress target-value),
      completed-at: (if (>= new-progress target-value) (some stacks-block-height) none)
    }))
    
    ;; If completed, award achievement
    (if (>= new-progress target-value)
      (begin
        (try! (award-achievement achievement-id user))
        (ok progress-percentage)
      )
      (ok progress-percentage)
    )
  )
)

;; Award achievement badge and tokens
(define-public (award-achievement (achievement-id uint) (user principal))
  (let (
    (achievement (unwrap! (map-get? skill-achievements achievement-id) ERR_ACHIEVEMENT_NOT_FOUND))
    (progress-data (unwrap! (map-get? user-achievement-progress { achievement-id: achievement-id, user: user }) ERR_ACHIEVEMENT_NOT_FOUND))
    (reward-tokens (get reward-tokens achievement))
  )
    (asserts! (get completed progress-data) ERR_GOAL_NOT_MET)
    (asserts! (is-none (map-get? earned-achievements { user: user, achievement-id: achievement-id })) ERR_ALREADY_COMPLETED)
    
    ;; Award achievement badge
    (map-set earned-achievements { user: user, achievement-id: achievement-id } {
      completed-at: stacks-block-height,
      final-progress: (get current-progress progress-data),
      badge-earned: true,
      tokens-earned: reward-tokens
    })
    
    ;; Token rewards would be handled by integration with main Skillchain contract
    ;; For now, we just track the tokens that would be earned
    
    ;; Update user achievement statistics
    (let (
      (current-stats (unwrap! (map-get? user-achievement-stats { user: user }) ERR_UNAUTHORIZED))
      (new-completed (+ (get completed-achievements current-stats) u1))
      (new-rate (/ (* new-completed u100) (get total-achievements current-stats)))
      (new-streak (+ (get achievement-streak current-stats) u1))
    )
      (map-set user-achievement-stats { user: user } (merge current-stats {
        completed-achievements: new-completed,
        completion-rate: new-rate,
        total-tokens-earned: (+ (get total-tokens-earned current-stats) reward-tokens),
        achievement-streak: new-streak,
        last-completion: stacks-block-height
      }))
    )
    
    (ok reward-tokens)
  )
)

;; Read-only functions

(define-read-only (get-achievement (achievement-id uint))
  (map-get? skill-achievements achievement-id)
)

(define-read-only (get-user-progress (achievement-id uint) (user principal))
  (map-get? user-achievement-progress { achievement-id: achievement-id, user: user })
)

(define-read-only (get-earned-achievement (user principal) (achievement-id uint))
  (map-get? earned-achievements { user: user, achievement-id: achievement-id })
)

(define-read-only (get-user-achievement-stats (user principal))
  (map-get? user-achievement-stats { user: user })
)

(define-read-only (is-achievement-completed (achievement-id uint) (user principal))
  (match (map-get? user-achievement-progress { achievement-id: achievement-id, user: user })
    progress (get completed progress)
    false
  )
)

(define-read-only (calculate-achievement-difficulty (achievement-id uint))
  (match (map-get? skill-achievements achievement-id)
    achievement (let (
      (target-value (get target-value achievement))
      (target-type (get target-type achievement))
    )
      (if (is-eq target-type "endorsements")
        (if (> target-value u50) u3 (if (> target-value u20) u2 u1))
        (if (is-eq target-type "reputation")
          (if (> target-value u500) u3 (if (> target-value u200) u2 u1))
          u2
        )
      )
    )
    u0
  )
)

(define-read-only (get-total-achievements-count)
  (var-get achievement-counter)
)

(define-read-only (list-active-achievements-by-category (category (string-ascii 30)))
  ;; In a full implementation, this would return a list of achievement IDs
  ;; For now, return a simple count placeholder
  u0
)
