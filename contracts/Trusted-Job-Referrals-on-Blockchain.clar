(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-DUPLICATE-ENTRY (err u102))
(define-constant ERR-NOT-FOUND (err u103))
(define-constant ERR-EXPIRED (err u104))

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

(define-map reputation-scores
    { user: principal }
    {
        score: uint,
        total-referrals: uint,
        successful-referrals: uint,
        last-updated: uint
    }
)

(define-map referral-ratings
    { candidate: principal, referrer: principal }
    {
        rating: uint,
        feedback: (string-ascii 200),
        rated-by: principal,
        timestamp: uint
    }
)

(define-public (rate-referral 
    (candidate principal)
    (referrer principal)
    (rating uint)
    (feedback (string-ascii 200)))
    
    (let ((rating-key { candidate: candidate, referrer: referrer }))
        (asserts! (is-eq tx-sender candidate) ERR-NOT-AUTHORIZED)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-INPUT)
        (asserts! (is-some (map-get? referrals { candidate: candidate, referrer: referrer })) ERR-NOT-FOUND)
        (asserts! (is-none (map-get? referral-ratings rating-key)) ERR-DUPLICATE-ENTRY)
        
        (map-set referral-ratings
            rating-key
            {
                rating: rating,
                feedback: feedback,
                rated-by: tx-sender,
                timestamp: stacks-block-height
            }
        )
        
        (update-reputation-score referrer rating)
        (ok true)
    )
)

(define-private (update-reputation-score (user principal) (new-rating uint))
    (let ((current-rep (default-to 
            { score: u0, total-referrals: u0, successful-referrals: u0, last-updated: u0 }
            (map-get? reputation-scores { user: user }))))
        
        (let ((new-successful (if (>= new-rating u4) 
                (+ (get successful-referrals current-rep) u1)
                (get successful-referrals current-rep)))
              (new-total (+ (get total-referrals current-rep) u1)))
            
            (map-set reputation-scores
                { user: user }
                {
                    score: (calculate-reputation-score new-successful new-total user),
                    total-referrals: new-total,
                    successful-referrals: new-successful,
                    last-updated: stacks-block-height
                }
            )
        )
    )
)

(define-private (calculate-reputation-score (successful uint) (total uint) (user principal))
    (if (is-eq total u0)
        u0
        (let ((base-score (* (/ (* successful u100) total) u10))
              (verification-bonus (if (get verified (default-to 
                    { name: "", title: "", company: "", verified: false }
                    (map-get? user-profiles { user: user }))) u200 u0)))
            (+ base-score verification-bonus)
        )
    )
)

(define-read-only (get-reputation-score (user principal))
    (map-get? reputation-scores { user: user })
)

(define-read-only (get-referral-rating (candidate principal) (referrer principal))
    (map-get? referral-ratings { candidate: candidate, referrer: referrer })
)

(define-fungible-token referral-points)

(define-map reward-balances
    { user: principal }
    { balance: uint }
)

(define-map reward-claims
    { user: principal, claim-id: uint }
    {
        amount: uint,
        reason: (string-ascii 100),
        timestamp: uint,
        processed: bool
    }
)

(define-map user-claim-counters
    { user: principal }
    { counter: uint }
)

(define-data-var reward-rates 
    { successful-referral: uint, verification-bonus: uint, tip-multiplier: uint }
    { successful-referral: u100, verification-bonus: u50, tip-multiplier: u2 }
)

(define-data-var referral-expiry-period uint u144)

(define-map expired-referrals
    { candidate: principal, referrer: principal }
    { expired-at: uint }
)

(define-public (claim-referral-reward (candidate principal) (referrer principal))
    (let ((referral-data (unwrap! (get-referral candidate referrer) ERR-NOT-FOUND))
          (rating-data (unwrap! (get-referral-rating candidate referrer) ERR-NOT-FOUND)))
        
        (asserts! (is-eq tx-sender referrer) ERR-NOT-AUTHORIZED)
        (asserts! (>= (get rating rating-data) u4) ERR-INVALID-INPUT)
        
        (let ((reward-amount (calculate-reward-amount referrer (get rating rating-data)))
              (claim-counter (get counter (default-to { counter: u0 } 
                    (map-get? user-claim-counters { user: referrer })))))
            
            (map-set reward-claims
                { user: referrer, claim-id: claim-counter }
                {
                    amount: reward-amount,
                    reason: "successful-referral",
                    timestamp: stacks-block-height,
                    processed: true
                }
            )
            
            (map-set user-claim-counters
                { user: referrer }
                { counter: (+ claim-counter u1) }
            )
            
            (try! (ft-mint? referral-points reward-amount referrer))
            (update-reward-balance referrer reward-amount)
            (ok reward-amount)
        )
    )
)

(define-public (tip-referrer (referrer principal) (amount uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-INPUT)
        (asserts! (not (is-eq tx-sender referrer)) ERR-INVALID-INPUT)
        
        (let ((tip-amount (* amount (get tip-multiplier (var-get reward-rates)))))
            (try! (ft-mint? referral-points tip-amount referrer))
            (update-reward-balance referrer tip-amount)
            (ok tip-amount)
        )
    )
)

(define-private (calculate-reward-amount (user principal) (rating uint))
    (let ((base-reward (get successful-referral (var-get reward-rates)))
          (rating-multiplier rating)
          (verification-bonus (if (get verified (default-to 
                { name: "", title: "", company: "", verified: false }
                (map-get? user-profiles { user: user }))) 
            (get verification-bonus (var-get reward-rates)) u0)))
        
        (+ (* base-reward rating-multiplier) verification-bonus)
    )
)

(define-private (update-reward-balance (user principal) (amount uint))
    (let ((current-balance (get balance (default-to { balance: u0 } 
            (map-get? reward-balances { user: user })))))
        (map-set reward-balances
            { user: user }
            { balance: (+ current-balance amount) }
        )
    )
)

(define-public (update-reward-rates 
    (successful-referral uint) 
    (verification-bonus uint) 
    (tip-multiplier uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (var-set reward-rates {
            successful-referral: successful-referral,
            verification-bonus: verification-bonus,
            tip-multiplier: tip-multiplier
        })
        (ok true)
    )
)

(define-read-only (get-reward-balance (user principal))
    (map-get? reward-balances { user: user })
)

(define-read-only (get-reward-claim (user principal) (claim-id uint))
    (map-get? reward-claims { user: user, claim-id: claim-id })
)

(define-read-only (get-user-claim-counter (user principal))
    (map-get? user-claim-counters { user: user })
)

(define-read-only (get-reward-rates)
    (var-get reward-rates)
)

(define-read-only (get-token-balance (user principal))
    (ft-get-balance referral-points user)
)

(define-public (expire-referral (candidate principal) (referrer principal))
    (let ((referral-key { candidate: candidate, referrer: referrer }))
        (let ((referral-data (unwrap! (map-get? referrals referral-key) ERR-NOT-FOUND)))
            (asserts! (>= (- stacks-block-height (get timestamp referral-data)) (var-get referral-expiry-period)) ERR-INVALID-INPUT)
            (asserts! (is-none (map-get? expired-referrals referral-key)) ERR-DUPLICATE-ENTRY)
            
            (map-set expired-referrals
                referral-key
                { expired-at: stacks-block-height }
            )
            (ok true)
        )
    )
)

(define-public (renew-referral 
    (candidate principal)
    (role (string-ascii 50))
    (company (string-ascii 50))
    (relationship (string-ascii 50))
    (performance-notes (string-ascii 200))
    (start-date uint)
    (end-date uint))
    
    (let ((referral-key { candidate: candidate, referrer: tx-sender }))
        (asserts! (is-some (map-get? expired-referrals referral-key)) ERR-NOT-FOUND)
        (asserts! (not (is-eq tx-sender candidate)) ERR-INVALID-INPUT)
        
        (map-delete expired-referrals referral-key)
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
        (ok true)
    )
)

(define-public (set-expiry-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (> new-period u0) ERR-INVALID-INPUT)
        (var-set referral-expiry-period new-period)
        (ok true)
    )
)

(define-read-only (is-referral-expired (candidate principal) (referrer principal))
    (is-some (map-get? expired-referrals { candidate: candidate, referrer: referrer }))
)

(define-read-only (check-referral-expiry (candidate principal) (referrer principal))
    (let ((referral-data (map-get? referrals { candidate: candidate, referrer: referrer })))
        (match referral-data
            data (>= (- stacks-block-height (get timestamp data)) (var-get referral-expiry-period))
            false
        )
    )
)

(define-read-only (get-expiry-period)
    (var-get referral-expiry-period)
)

(define-read-only (get-expired-referral (candidate principal) (referrer principal))
    (map-get? expired-referrals { candidate: candidate, referrer: referrer })
)