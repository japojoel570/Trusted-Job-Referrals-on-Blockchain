(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-DUPLICATE-ENTRY (err u102))
(define-constant ERR-NOT-FOUND (err u103))

(define-map referrals 
    { candidate: principal, referrer: principal } 
    {
        role: (string-ascii 50),
        company: (string-ascii 50),
        relationship: (string-ascii 50),
        performance-notes: (string-ascii 200),
        start-date: uint,
        end-date: uint,
        timestamp: uint
    }
)

(define-map user-profiles
    { user: principal }
    {
        name: (string-ascii 50),
        title: (string-ascii 50),
        company: (string-ascii 50),
        verified: bool
    }
)

(define-map referral-counts
    { candidate: principal }
    { count: uint }
)

(define-public (create-profile (name (string-ascii 50)) (title (string-ascii 50)) (company (string-ascii 50)))
    (ok (map-set user-profiles
        { user: tx-sender }
        {
            name: name,
            title: title,
            company: company,
            verified: false
        }
    ))
)

(define-public (verify-profile (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set user-profiles
            { user: user }
            (merge (unwrap! (get-profile user) ERR-INVALID-INPUT)
                { verified: true })
        ))
    )
)

(define-public (add-referral 
    (candidate principal)
    (role (string-ascii 50))
    (company (string-ascii 50))
    (relationship (string-ascii 50))
    (performance-notes (string-ascii 200))
    (start-date uint)
    (end-date uint))
    
    (let ((referral-key { candidate: candidate, referrer: tx-sender }))
        (asserts! (is-none (map-get? referrals referral-key)) ERR-DUPLICATE-ENTRY)
        (asserts! (not (is-eq tx-sender candidate)) ERR-INVALID-INPUT)
        
        (map-set referrals
            referral-key
            {
                role: role,
                company: company,
                relationship: relationship,
                performance-notes: performance-notes,
                start-date: start-date,
                end-date: end-date,
                timestamp: stacks-block-height
            }
        )
        
        (increment-referral-count candidate)
        (ok true)
    )
)

(define-private (increment-referral-count (candidate principal))
    (let ((current-count (default-to { count: u0 } (map-get? referral-counts { candidate: candidate }))))
        (map-set referral-counts
            { candidate: candidate }
            { count: (+ (get count current-count) u1) }
        )
    )
)

(define-read-only (get-profile (user principal))
    (map-get? user-profiles { user: user })
)

(define-read-only (get-referral (candidate principal) (referrer principal))
    (map-get? referrals { candidate: candidate, referrer: referrer })
)

(define-read-only (get-referral-count (candidate principal))
    (default-to { count: u0 }
        (map-get? referral-counts { candidate: candidate })
    )
)
