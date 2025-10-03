;; Decentralized Task Management Protocol Smart Contract
;; A blockchain-based system for distributed team coordination featuring automated task 
;; assignment, milestone tracking, reputation scoring, and cryptocurrency-based compensation
;; for remote workers and decentralized autonomous organizations (DAOs)

;; Error codes for operation failures
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-PROJECT-NOT-FOUND (err u101))
(define-constant ERR-TASK-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STATUS-TRANSITION (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-PROJECT-ALREADY-EXISTS (err u105))
(define-constant ERR-TASK-ALREADY-EXISTS (err u106))
(define-constant ERR-INVALID-INPUT (err u107))
(define-constant ERR-MEMBER-ALREADY-ADDED (err u108))
(define-constant ERR-TEAM-CAPACITY-EXCEEDED (err u109))

;; Protocol configuration constants
(define-constant max-team-size u20)
(define-constant min-reputation-score u1)
(define-constant max-reputation-score u5)
(define-constant project-id-sequence-key "project-sequence")
(define-constant status-active "active")
(define-constant status-pending "pending")
(define-constant status-completed "completed")

;; Core project data structure storing all project metadata and team information
(define-map projects
    { project-id: uint }
    {
        owner: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        allocated-budget: uint,
        status: (string-ascii 20),
        created-at-block: uint,
        team: (list 20 principal)
    }
)

;; Task registry linking tasks to projects with assignment and payment details
(define-map tasks
    { project-id: uint, task-id: uint }
    {
        assignee: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        due-block: uint,
        compensation: uint,
        status: (string-ascii 20),
        created-at-block: uint
    }
)

;; Global sequence tracker for generating unique project identifiers
(define-map id-sequences
    { sequence-name: (string-ascii 20) }
    { next-id: uint }
)

;; Per-project task counter for generating unique task identifiers within each project
(define-map task-sequences
    { project-id: uint }
    { next-task-id: uint }
)

;; Worker reputation and performance metrics for decentralized credibility system
(define-map contributor-profiles
    { address: principal }
    {
        tasks-completed: uint,
        total-earnings: uint,
        reputation-score: uint,
        total-ratings: uint
    }
)

;; Verify if the given user is the owner of the specified project
(define-private (is-owner (project-id uint) (user principal))
    (match (map-get? projects { project-id: project-id })
        project-data (is-eq (get owner project-data) user)
        false
    )
)

;; Check if user has access to project as either owner or team member
(define-private (has-project-access (project-id uint) (user principal))
    (match (map-get? projects { project-id: project-id })
        project-data (or
            (is-eq (get owner project-data) user)
            (is-some (index-of (get team project-data) user))
        )
        false
    )
)

;; Validate project creation parameters for completeness and correctness
(define-private (is-valid-project-data (title (string-ascii 50)) (description (string-ascii 500)) (budget uint))
    (and 
        (> (len title) u0)
        (> (len description) u0)
        (> budget u0)
    )
)

;; Validate task assignment ensuring worker is part of the project team
(define-private (is-valid-task-data (project-data {owner: principal, title: (string-ascii 50), description: (string-ascii 500), allocated-budget: uint, status: (string-ascii 20), created-at-block: uint, team: (list 20 principal)}) (title (string-ascii 50)) (description (string-ascii 500)) (assignee principal) (deadline uint) (payment uint))
    (and 
        (> (len title) u0)
        (> (len description) u0)
        (> deadline block-height)
        (> payment u0)
        (or
            (is-eq assignee (get owner project-data))
            (is-some (index-of (get team project-data) assignee))
        )
    )
)

;; Comprehensive input validation for all function parameters
(define-private (validate-inputs (title-opt (optional (string-ascii 50))) (desc-opt (optional (string-ascii 500))) (budget-opt (optional uint)) (project-opt (optional uint)) (task-opt (optional uint)) (status-opt (optional (string-ascii 20))) (user-opt (optional principal)) (rating-opt (optional uint)))
    (let ((is-title-valid (match title-opt
                        val (> (len val) u0)
                        true))
          (is-desc-valid (match desc-opt
                        val (> (len val) u0)
                        true))
          (is-budget-valid (match budget-opt
                          val (> val u0)
                          true))
          (is-project-valid (match project-opt
                           val (>= val u0)
                           true))
          (is-task-valid (match task-opt
                        val (>= val u0)
                        true))
          (is-status-valid (match status-opt
                          val (> (len val) u0)
                          true))
          (is-rating-valid (match rating-opt
                          val (and (>= val min-reputation-score) 
                                   (<= val max-reputation-score))
                          true)))
        (and is-title-valid is-desc-valid is-budget-valid is-project-valid is-task-valid is-status-valid is-rating-valid)))

;; Generate next available project identifier from global sequence
(define-private (generate-project-id)
    (let ((current-sequence (default-to { next-id: u0 } 
                                     (map-get? id-sequences { sequence-name: project-id-sequence-key }))))
        (begin
            (map-set id-sequences 
                    { sequence-name: project-id-sequence-key } 
                    { next-id: (+ (get next-id current-sequence) u1) })
            (get next-id current-sequence)
        )
    )
)

;; Generate next task identifier for a specific project
(define-private (generate-task-id (project-id uint))
    (match (map-get? projects { project-id: project-id })
        project-data 
            (let ((current-sequence (default-to { next-task-id: u0 } 
                                          (map-get? task-sequences { project-id: project-id }))))
                (begin
                    (map-set task-sequences 
                            { project-id: project-id } 
                            { next-task-id: (+ (get next-task-id current-sequence) u1) })
                    (ok (get next-task-id current-sequence))
                )
            )
        ERR-PROJECT-NOT-FOUND
    )
)

;; Initialize a new project with budget allocation and creator as owner
(define-public (create-project (title (string-ascii 50)) (description (string-ascii 500)) (budget uint))
    (let ((new-id (generate-project-id))
          (creator tx-sender))
        (asserts! (validate-inputs (some title) (some description) 
                                            (some budget) none none none none none) 
                 ERR-INVALID-INPUT)
        (asserts! (is-valid-project-data title description budget)
                 ERR-INVALID-INPUT)
        (map-set projects
            { project-id: new-id }
            {
                owner: creator,
                title: title,
                description: description,
                allocated-budget: budget,
                status: status-active,
                created-at-block: block-height,
                team: (list)
            }
        )
        (ok new-id)
    )
)

;; Add a new contributor to the project team (owner only)
(define-public (add-member (project-id uint) (member principal))
    (let ((caller tx-sender))
        (asserts! (validate-inputs none none none (some project-id) 
                                            none none (some member) none)
                 ERR-INVALID-INPUT)
        (match (map-get? projects { project-id: project-id })
            project-data
                (begin
                    (asserts! (is-eq (get owner project-data) caller)
                             ERR-UNAUTHORIZED-ACCESS)
                    (asserts! (is-none (index-of (get team project-data) member))
                             ERR-MEMBER-ALREADY-ADDED)
                    (asserts! (< (len (get team project-data)) max-team-size)
                             ERR-TEAM-CAPACITY-EXCEEDED)
                    (let ((updated-team (unwrap! (as-max-len? 
                                                   (append (get team project-data) member) 
                                                   u20) 
                                                  ERR-TEAM-CAPACITY-EXCEEDED)))
                        (map-set projects
                            { project-id: project-id }
                            (merge project-data { team: updated-team })
                        )
                        (ok true)
                    )
                )
            ERR-PROJECT-NOT-FOUND
        )
    )
)

;; Create and assign a new task to a project team member with compensation details
(define-public (assign-task (project-id uint) (title (string-ascii 50)) (description (string-ascii 500)) (assignee principal) (deadline uint) (payment uint))
    (let ((caller tx-sender))
        (asserts! (validate-inputs (some title) (some description) 
                                            (some payment) (some project-id) 
                                            none none (some assignee) none)
                 ERR-INVALID-INPUT)
        (asserts! (> deadline block-height) ERR-INVALID-INPUT)
        (match (map-get? projects { project-id: project-id })
            project-data
                (begin
                    (asserts! (is-eq (get owner project-data) caller)
                             ERR-UNAUTHORIZED-ACCESS)
                    (asserts! (is-valid-task-data project-data 
                                                       title 
                                                       description 
                                                       assignee 
                                                       deadline 
                                                       payment)
                             ERR-INVALID-INPUT)
                    (match (generate-task-id project-id)
                        new-task-id
                            (begin
                                (map-set tasks
                                    { project-id: project-id, task-id: new-task-id }
                                    {
                                        assignee: assignee,
                                        title: title,
                                        description: description,
                                        due-block: deadline,
                                        compensation: payment,
                                        status: status-pending,
                                        created-at-block: block-height
                                    }
                                )
                                (ok new-task-id)
                            )
                        error ERR-PROJECT-NOT-FOUND
                    )
                )
            ERR-PROJECT-NOT-FOUND
        )
    )
)

;; Update task status by authorized users (owner or assignee)
(define-public (update-task-status (project-id uint) (task-id uint) (new-status (string-ascii 20)))
    (let ((caller tx-sender))
        (asserts! (validate-inputs none none none (some project-id) 
                                            (some task-id) (some new-status) none none)
                 ERR-INVALID-INPUT)
        (match (map-get? projects { project-id: project-id })
            project-data
                (match (map-get? tasks { project-id: project-id, task-id: task-id })
                    task-data
                        (begin
                            (asserts! (or (is-eq (get owner project-data) caller) 
                                         (is-eq (get assignee task-data) caller))
                                     ERR-UNAUTHORIZED-ACCESS)
                            (map-set tasks
                                { project-id: project-id, task-id: task-id }
                                (merge task-data { status: new-status })
                            )
                            (ok true)
                        )
                    ERR-TASK-NOT-FOUND
                )
            ERR-PROJECT-NOT-FOUND
        )
    )
)

;; Complete task and trigger automatic payment to assignee
(define-public (complete-task-with-payment (project-id uint) (task-id uint))
    (let ((caller tx-sender))
        (asserts! (validate-inputs none none none (some project-id) 
                                            (some task-id) none none none)
                 ERR-INVALID-INPUT)
        (match (map-get? projects { project-id: project-id })
            project-data
                (match (map-get? tasks { project-id: project-id, task-id: task-id })
                    task-data
                        (begin
                            (asserts! (is-eq (get assignee task-data) caller)
                                     ERR-UNAUTHORIZED-ACCESS)
                            (asserts! (is-eq (get status task-data) status-pending)
                                     ERR-INVALID-STATUS-TRANSITION)
                            (try! (stx-transfer? (get compensation task-data) 
                                               (get owner project-data) 
                                               caller))
                            (map-set tasks
                                { project-id: project-id, task-id: task-id }
                                (merge task-data { status: status-completed })
                            )
                            (update-contributor-metrics caller (get compensation task-data))
                            (ok true)
                        )
                    ERR-TASK-NOT-FOUND
                )
            ERR-PROJECT-NOT-FOUND
        )
    )
)

;; Update contributor performance metrics after task completion
(define-private (update-contributor-metrics (contributor principal) (earnings uint))
    (let ((current-profile (default-to
            { tasks-completed: u0, total-earnings: u0, reputation-score: u0, total-ratings: u0 }
            (map-get? contributor-profiles { address: contributor })
        )))
        (map-set contributor-profiles
            { address: contributor }
            {
                tasks-completed: (+ (get tasks-completed current-profile) u1),
                total-earnings: (+ (get total-earnings current-profile) earnings),
                reputation-score: (get reputation-score current-profile),
                total-ratings: (get total-ratings current-profile)
            }
        )
    )
)

;; Submit reputation rating for a contributor
(define-public (rate-contributor (contributor principal) (rating uint))
    (begin
        (asserts! (validate-inputs none none none none none none 
                                            (some contributor) (some rating))
                 ERR-INVALID-INPUT)
        (let ((current-profile (default-to
                { tasks-completed: u0, total-earnings: u0, reputation-score: u0, total-ratings: u0 }
                (map-get? contributor-profiles { address: contributor })
            )))
            (map-set contributor-profiles
                { address: contributor }
                {
                    tasks-completed: (get tasks-completed current-profile),
                    total-earnings: (get total-earnings current-profile),
                    reputation-score: (/ (+ (* (get reputation-score current-profile) 
                                           (get total-ratings current-profile)) 
                                         rating) 
                                      (+ (get total-ratings current-profile) u1)),
                    total-ratings: (+ (get total-ratings current-profile) u1)
                }
            )
            (ok true)
        )
    )
)

;; Retrieve complete project information by project identifier
(define-read-only (get-project-details (project-id uint))
    (begin
        (asserts! (validate-inputs none none none (some project-id) 
                                            none none none none) 
                 none)
        (map-get? projects { project-id: project-id })
    )
)

;; Retrieve task details by project and task identifier
(define-read-only (get-task-details (project-id uint) (task-id uint))
    (begin
        (asserts! (validate-inputs none none none (some project-id) 
                                            (some task-id) none none none)
                 none)
        (map-get? tasks { project-id: project-id, task-id: task-id })
    )
)

;; Retrieve contributor performance metrics and reputation
(define-read-only (get-contributor-profile (contributor principal))
    (map-get? contributor-profiles { address: contributor })
)

;; Verify if user has access to the specified project
(define-read-only (verify-project-access (project-id uint) (user principal))
    (begin
        (asserts! (validate-inputs none none none (some project-id) 
                                            none none (some user) none)
                 false)
        (has-project-access project-id user)
    )
)

;; Verify if user is the owner of the specified project
(define-read-only (verify-project-ownership (project-id uint) (user principal))
    (begin
        (asserts! (validate-inputs none none none (some project-id) 
                                            none none (some user) none)
                 false)
        (is-owner project-id user)
    )
)