;; LiquidQuartz Simple Staking Contract
;; A basic staking contract for educational purposes

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-enough-balance (err u101))
(define-constant err-no-stake-found (err u102))
(define-constant err-already-staked (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-contract-paused (err u105))
(define-constant err-insufficient-rewards (err u106))
(define-constant err-minimum-stake-not-met (err u107))
(define-constant err-lock-period-active (err u108))
(define-constant err-invalid-tier (err u109))

;; Staking tiers with different reward rates
(define-constant tier-bronze u1)
(define-constant tier-silver u2)
(define-constant tier-gold u3)
(define-constant tier-platinum u4)

(define-constant min-stake-bronze u1000)
(define-constant min-stake-silver u5000)
(define-constant min-stake-gold u10000)
(define-constant min-stake-platinum u50000)

(define-constant reward-rate-bronze u5)
(define-constant reward-rate-silver u7)
(define-constant reward-rate-gold u10)
(define-constant reward-rate-platinum u15)

(define-constant lock-period-blocks u144) ;; Approximately 1 day

;; Data Variables
(define-data-var total-staked uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var contract-paused bool false)
(define-data-var minimum-stake-amount uint u100)
(define-data-var total-stakers uint u0)
(define-data-var reward-pool uint u1000000)

;; Data Maps
(define-map stakes
  principal
  {
    amount: uint,
    start-block: uint,
    last-claim-block: uint,
    tier: uint,
    total-claimed: uint
  }
)

(define-map staker-stats
  principal
  {
    total-staked-lifetime: uint,
    total-rewards-lifetime: uint,
    stake-count: uint
  }
)

(define-map whitelist principal bool)

;; Read-only functions
(define-read-only (get-stake (user principal))
  (map-get? stakes user)
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-total-stakers)
  (var-get total-stakers)
)

(define-read-only (get-minimum-stake)
  (var-get minimum-stake-amount)
)

(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

(define-read-only (get-reward-pool)
  (var-get reward-pool)
)

(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed)
)

(define-read-only (get-staker-stats (user principal))
  (map-get? staker-stats user)
)

(define-read-only (is-whitelisted (user principal))
  (default-to false (map-get? whitelist user))
)

(define-read-only (get-tier-info (amount uint))
  (if (>= amount min-stake-platinum)
    (ok {tier: tier-platinum, rate: reward-rate-platinum, name: "Platinum"})
    (if (>= amount min-stake-gold)
      (ok {tier: tier-gold, rate: reward-rate-gold, name: "Gold"})
      (if (>= amount min-stake-silver)
        (ok {tier: tier-silver, rate: reward-rate-silver, name: "Silver"})
        (if (>= amount min-stake-bronze)
          (ok {tier: tier-bronze, rate: reward-rate-bronze, name: "Bronze"})
          (err err-minimum-stake-not-met)
        )
      )
    )
  )
)

(define-read-only (get-stake-tier (user principal))
  (match (map-get? stakes user)
    stake-info (ok (get tier stake-info))
    (err err-no-stake-found)
  )
)

(define-read-only (calculate-rewards (user principal))
  (match (map-get? stakes user)
    stake-info
      (let
        (
          (blocks-staked (- block-height (get last-claim-block stake-info)))
          (staked-amount (get amount stake-info))
          (tier (get tier stake-info))
          (rate (if (is-eq tier tier-platinum)
                  reward-rate-platinum
                  (if (is-eq tier tier-gold)
                    reward-rate-gold
                    (if (is-eq tier tier-silver)
                      reward-rate-silver
                      reward-rate-bronze
                    )
                  )
                ))
          (rewards (/ (* (* staked-amount blocks-staked) rate) u100000))
        )
        (ok rewards)
      )
    (err err-no-stake-found)
  )
)

(define-read-only (can-unstake (user principal))
  (match (map-get? stakes user)
    stake-info
      (let
        (
          (blocks-since-stake (- block-height (get start-block stake-info)))
        )
        (ok (>= blocks-since-stake lock-period-blocks))
      )
    (err err-no-stake-found)
  )
)

(define-read-only (get-contract-stats)
  (ok {
    total-staked: (var-get total-staked),
    total-stakers: (var-get total-stakers),
    total-rewards-distributed: (var-get total-rewards-distributed),
    reward-pool: (var-get reward-pool),
    paused: (var-get contract-paused)
  })
)

;; Public functions
(define-public (stake (amount uint))
  (let
    (
      (sender tx-sender)
      (existing-stake (map-get? stakes sender))
      (tier-result (unwrap! (get-tier-info amount) err-minimum-stake-not-met))
      (stats (default-to {total-staked-lifetime: u0, total-rewards-lifetime: u0, stake-count: u0}
                         (map-get? staker-stats sender)))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= amount (var-get minimum-stake-amount)) err-minimum-stake-not-met)
    (asserts! (is-none existing-stake) err-already-staked)
    
    ;; Record the stake
    (map-set stakes sender {
      amount: amount,
      start-block: block-height,
      last-claim-block: block-height,
      tier: (get tier tier-result),
      total-claimed: u0
    })
    
    ;; Update staker stats
    (map-set staker-stats sender {
      total-staked-lifetime: (+ (get total-staked-lifetime stats) amount),
      total-rewards-lifetime: (get total-rewards-lifetime stats),
      stake-count: (+ (get stake-count stats) u1)
    })
    
    ;; Update total staked and stakers count
    (var-set total-staked (+ (var-get total-staked) amount))
    (if (is-eq (get stake-count stats) u0)
      (var-set total-stakers (+ (var-get total-stakers) u1))
      true
    )
    
    (ok true)
  )
)

(define-public (claim-rewards)
  (let
    (
      (sender tx-sender)
      (stake-info (unwrap! (map-get? stakes sender) err-no-stake-found))
      (rewards (unwrap! (calculate-rewards sender) err-no-stake-found))
      (stats (default-to {total-staked-lifetime: u0, total-rewards-lifetime: u0, stake-count: u0}
                         (map-get? staker-stats sender)))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (<= rewards (var-get reward-pool)) err-insufficient-rewards)
    
    ;; Update last claim block and total claimed
    (map-set stakes sender (merge stake-info {
      last-claim-block: block-height,
      total-claimed: (+ (get total-claimed stake-info) rewards)
    }))
    
    ;; Update staker stats
    (map-set staker-stats sender (merge stats {
      total-rewards-lifetime: (+ (get total-rewards-lifetime stats) rewards)
    }))
    
    ;; Update contract stats
    (var-set reward-pool (- (var-get reward-pool) rewards))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
    
    (ok rewards)
  )
)

(define-public (unstake)
  (let
    (
      (sender tx-sender)
      (stake-info (unwrap! (map-get? stakes sender) err-no-stake-found))
      (staked-amount (get amount stake-info))
      (rewards (unwrap! (calculate-rewards sender) err-no-stake-found))
      (can-unstake-now (unwrap! (can-unstake sender) err-no-stake-found))
      (stats (default-to {total-staked-lifetime: u0, total-rewards-lifetime: u0, stake-count: u0}
                         (map-get? staker-stats sender)))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! can-unstake-now err-lock-period-active)
    (asserts! (<= rewards (var-get reward-pool)) err-insufficient-rewards)
    
    ;; Remove stake
    (map-delete stakes sender)
    
    ;; Update staker stats
    (map-set staker-stats sender (merge stats {
      total-rewards-lifetime: (+ (get total-rewards-lifetime stats) rewards)
    }))
    
    ;; Update contract stats
    (var-set total-staked (- (var-get total-staked) staked-amount))
    (var-set reward-pool (- (var-get reward-pool) rewards))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
    
    (ok {
      amount: staked-amount,
      rewards: rewards
    })
  )
)

(define-public (increase-stake (additional-amount uint))
  (let
    (
      (sender tx-sender)
      (stake-info (unwrap! (map-get? stakes sender) err-no-stake-found))
      (current-amount (get amount stake-info))
      (new-amount (+ current-amount additional-amount))
      (tier-result (unwrap! (get-tier-info new-amount) err-minimum-stake-not-met))
      (stats (default-to {total-staked-lifetime: u0, total-rewards-lifetime: u0, stake-count: u0}
                         (map-get? staker-stats sender)))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (> additional-amount u0) err-invalid-amount)
    
    ;; Update stake amount and potentially tier
    (map-set stakes sender (merge stake-info {
      amount: new-amount,
      tier: (get tier tier-result)
    }))
    
    ;; Update staker stats
    (map-set staker-stats sender (merge stats {
      total-staked-lifetime: (+ (get total-staked-lifetime stats) additional-amount)
    }))
    
    ;; Update total staked
    (var-set total-staked (+ (var-get total-staked) additional-amount))
    
    (ok true)
  )
)

;; Admin functions
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (set-minimum-stake (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set minimum-stake-amount new-minimum)
    (ok true)
  )
)

(define-public (add-to-reward-pool (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)
  )
)

(define-public (add-to-whitelist (user principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set whitelist user true)
    (ok true)
  )
)

(define-public (remove-from-whitelist (user principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete whitelist user)
    (ok true)
  )
)