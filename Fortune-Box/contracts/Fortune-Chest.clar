;; Fortune Chest Smart Contract
;; A comprehensive loot box implementation with multiple tiers and robust error handling

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-INVALID-LOOT-TYPE (err u102))
(define-constant ERR-LOOT-BOX-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-OPENED (err u104))
(define-constant ERR-INVALID-PRICE (err u105))
(define-constant ERR-INVALID-TIER (err u106))
(define-constant ERR-INSUFFICIENT-INVENTORY (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))
(define-constant ERR-INVALID-RECIPIENT (err u109))
(define-constant ERR-CONTRACT-PAUSED (err u110))
(define-constant ERR-INVALID-RARITY (err u111))
(define-constant ERR-INVALID-RATE (err u112))
(define-constant ERR-ITEM-ALREADY-EXISTS (err u113))
(define-constant ERR-INVALID-VALUE (err u114))
(define-constant ERR-INVALID-SUPPLY (err u115))
(define-constant ERR-INVALID-SEED (err u116))
(define-constant ERR-INVALID-NAME (err u117))

;; Contract state variables
(define-data-var contract-owner principal tx-sender)
(define-data-var contract-paused bool false)
(define-data-var loot-box-counter uint u0)
(define-data-var total-revenue uint u0)
(define-data-var random-seed uint u12345)
(define-data-var last-loot-box-purchased uint u0)
(define-data-var last-loot-box-opened uint u0)

;; Tier constants
(define-constant TIER-COMMON u1)
(define-constant TIER-RARE u2)
(define-constant TIER-EPIC u3)
(define-constant TIER-LEGENDARY u4)

;; Maximum values for validation
(define-constant MAX-ITEM-VALUE u1000000000000) ;; 1 million STX in microSTX
(define-constant MAX-SUPPLY u10000)
(define-constant MAX-SEED u999999999)
(define-constant MAX-ITEM-ID u1000)

;; Data maps
(define-map loot-box-prices uint uint)
(define-map loot-boxes uint {
    owner: principal,
    tier: uint,
    is-opened: bool,
    purchase-id: uint,
    purchase-counter: uint
})
(define-map loot-items uint {
    name: (string-ascii 64),
    tier: uint,
    rarity: uint,
    value: uint,
    supply: uint,
    max-supply: uint
})
(define-map user-inventory {user: principal, item-id: uint} uint)
(define-map user-loot-boxes principal (list 100 uint))
(define-map tier-drop-rates {tier: uint, item-tier: uint} uint)

;; Helper functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner)))

(define-private (is-contract-active)
    (not (var-get contract-paused)))

(define-private (is-valid-tier (tier uint))
    (and (>= tier u1) (<= tier u4)))

(define-private (is-valid-item-id (item-id uint))
    (and (> item-id u0) (<= item-id MAX-ITEM-ID)))

(define-private (is-valid-principal (recipient principal))
    (and 
        (not (is-eq recipient tx-sender))
        (not (is-eq recipient (as-contract tx-sender)))))

(define-private (is-valid-item-name (name (string-ascii 64)))
    (and 
        (> (len name) u0)
        (<= (len name) u64)
        (not (is-eq name ""))))

;; Random number generator using only safe variables
(define-private (generate-random-number (max uint))
    (let (
        (current-seed (var-get random-seed))
        (counter-value (var-get loot-box-counter))
        (entropy (+ 
            (* current-seed u13)
            (* counter-value u17)
            u1337
        ))
        (new-seed (mod (+ entropy u7919) u999999))
    )
    (var-set random-seed new-seed)
    (mod entropy max)))

;; Initialize contract with default values
(define-private (initialize-contract)
    (begin
        ;; Set loot box prices in microSTX
        (map-set loot-box-prices TIER-COMMON u1000000)    ;; 1 STX
        (map-set loot-box-prices TIER-RARE u5000000)      ;; 5 STX
        (map-set loot-box-prices TIER-EPIC u15000000)     ;; 15 STX
        (map-set loot-box-prices TIER-LEGENDARY u50000000) ;; 50 STX
        
        ;; Initialize loot items
        (map-set loot-items u1 {
            name: "Common Sword",
            tier: TIER-COMMON,
            rarity: u7000,
            value: u500000,
            supply: u0,
            max-supply: u1000
        })
        (map-set loot-items u2 {
            name: "Rare Shield",
            tier: TIER-RARE,
            rarity: u2500,
            value: u2000000,
            supply: u0,
            max-supply: u500
        })
        (map-set loot-items u3 {
            name: "Epic Armor",
            tier: TIER-EPIC,
            rarity: u450,
            value: u8000000,
            supply: u0,
            max-supply: u100
        })
        (map-set loot-items u4 {
            name: "Legendary Weapon",
            tier: TIER-LEGENDARY,
            rarity: u50,
            value: u40000000,
            supply: u0,
            max-supply: u25
        })
        
        ;; Set drop rates for common tier (out of 10000)
        (map-set tier-drop-rates {tier: TIER-COMMON, item-tier: TIER-COMMON} u9500)
        (map-set tier-drop-rates {tier: TIER-COMMON, item-tier: TIER-RARE} u450)
        (map-set tier-drop-rates {tier: TIER-COMMON, item-tier: TIER-EPIC} u45)
        (map-set tier-drop-rates {tier: TIER-COMMON, item-tier: TIER-LEGENDARY} u5)
        
        ;; Set drop rates for rare tier
        (map-set tier-drop-rates {tier: TIER-RARE, item-tier: TIER-COMMON} u6000)
        (map-set tier-drop-rates {tier: TIER-RARE, item-tier: TIER-RARE} u3200)
        (map-set tier-drop-rates {tier: TIER-RARE, item-tier: TIER-EPIC} u700)
        (map-set tier-drop-rates {tier: TIER-RARE, item-tier: TIER-LEGENDARY} u100)
        
        ;; Set drop rates for epic tier
        (map-set tier-drop-rates {tier: TIER-EPIC, item-tier: TIER-COMMON} u3000)
        (map-set tier-drop-rates {tier: TIER-EPIC, item-tier: TIER-RARE} u4000)
        (map-set tier-drop-rates {tier: TIER-EPIC, item-tier: TIER-EPIC} u2500)
        (map-set tier-drop-rates {tier: TIER-EPIC, item-tier: TIER-LEGENDARY} u500)
        
        ;; Set drop rates for legendary tier
        (map-set tier-drop-rates {tier: TIER-LEGENDARY, item-tier: TIER-COMMON} u1000)
        (map-set tier-drop-rates {tier: TIER-LEGENDARY, item-tier: TIER-RARE} u3000)
        (map-set tier-drop-rates {tier: TIER-LEGENDARY, item-tier: TIER-EPIC} u4000)
        (map-set tier-drop-rates {tier: TIER-LEGENDARY, item-tier: TIER-LEGENDARY} u2000)
        
        true))

;; Public functions

;; Purchase a loot box
(define-public (purchase-loot-box (tier uint))
    (let (
        (price (unwrap! (map-get? loot-box-prices tier) ERR-INVALID-TIER))
        (new-box-id (+ (var-get loot-box-counter) u1))
        (current-boxes (default-to (list) (map-get? user-loot-boxes tx-sender)))
    )
    (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
    (asserts! (is-valid-tier tier) ERR-INVALID-TIER)
    (asserts! (>= (stx-get-balance tx-sender) price) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
    
    ;; Create loot box
    (map-set loot-boxes new-box-id {
        owner: tx-sender,
        tier: tier,
        is-opened: false,
        purchase-id: new-box-id,
        purchase-counter: (var-get loot-box-counter)
    })
    
    ;; Update user's loot boxes if list isn't full
    (if (< (len current-boxes) u100)
        (map-set user-loot-boxes tx-sender 
            (unwrap-panic (as-max-len? (append current-boxes new-box-id) u100)))
        true)
    
    ;; Update counters
    (var-set loot-box-counter new-box-id)
    (var-set total-revenue (+ (var-get total-revenue) price))
    (var-set last-loot-box-purchased new-box-id)
    
    (ok new-box-id)))

;; Determine loot item based on tier and randomness
(define-private (determine-loot-item (tier uint) (random-num uint))
    (let (
        (roll (mod random-num u10000))
        (common-rate (default-to u0 (map-get? tier-drop-rates {tier: tier, item-tier: TIER-COMMON})))
        (rare-rate (+ common-rate (default-to u0 (map-get? tier-drop-rates {tier: tier, item-tier: TIER-RARE}))))
        (epic-rate (+ rare-rate (default-to u0 (map-get? tier-drop-rates {tier: tier, item-tier: TIER-EPIC}))))
    )
    (if (< roll common-rate)
        u1 ;; Common item
        (if (< roll rare-rate)
            u2 ;; Rare item
            (if (< roll epic-rate)
                u3 ;; Epic item
                u4))))) ;; Legendary item

;; Add item to user inventory
(define-private (add-to-inventory (user principal) (item-id uint) (quantity uint))
    (let (
        (current-quantity (default-to u0 (map-get? user-inventory {user: user, item-id: item-id})))
        (item-data (unwrap-panic (map-get? loot-items item-id)))
        (new-supply (+ (get supply item-data) quantity))
    )
    (asserts! (<= new-supply (get max-supply item-data)) ERR-INSUFFICIENT-INVENTORY)
    
    ;; Update user inventory
    (map-set user-inventory {user: user, item-id: item-id} (+ current-quantity quantity))
    
    ;; Update item supply
    (map-set loot-items item-id (merge item-data {supply: new-supply}))
    
    (ok true)))

;; Open a loot box
(define-public (open-loot-box (box-id uint))
    (let (
        (box-data (unwrap! (map-get? loot-boxes box-id) ERR-LOOT-BOX-NOT-FOUND))
        (random-num (generate-random-number u1000000))
        (loot-item (determine-loot-item (get tier box-data) random-num))
    )
    (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
    (asserts! (is-eq (get owner box-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-opened box-data)) ERR-ALREADY-OPENED)
    
    ;; Mark box as opened
    (map-set loot-boxes box-id (merge box-data {is-opened: true}))
    
    ;; Add loot to user inventory
    (try! (add-to-inventory tx-sender loot-item u1))
    
    ;; Update last opened box
    (var-set last-loot-box-opened box-id)
    
    (ok loot-item)))

;; Gift a loot box to another user
(define-public (gift-loot-box (box-id uint) (recipient principal))
    (let (
        (box-data (unwrap! (map-get? loot-boxes box-id) ERR-LOOT-BOX-NOT-FOUND))
        (recipient-boxes (default-to (list) (map-get? user-loot-boxes recipient)))
    )
    (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
    (asserts! (is-eq (get owner box-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-opened box-data)) ERR-ALREADY-OPENED)
    (asserts! (is-valid-principal recipient) ERR-INVALID-RECIPIENT)
    
    ;; Update ownership
    (map-set loot-boxes box-id (merge box-data {owner: recipient}))
    
    ;; Update recipient's loot boxes if list isn't full
    (if (< (len recipient-boxes) u100)
        (map-set user-loot-boxes recipient 
            (unwrap-panic (as-max-len? (append recipient-boxes box-id) u100)))
        true)
    
    (ok true)))

;; Admin functions

;; Update loot box price (admin only)
(define-public (update-loot-box-price (tier uint) (new-price uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-tier tier) ERR-INVALID-TIER)
        (asserts! (> new-price u0) ERR-INVALID-PRICE)
        
        (map-set loot-box-prices tier new-price)
        (ok true)))

;; Add new loot item (admin only)
(define-public (add-loot-item (item-id uint) (name (string-ascii 64)) (tier uint) (rarity uint) (value uint) (max-supply uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-item-id item-id) ERR-INVALID-LOOT-TYPE)
        (asserts! (is-none (map-get? loot-items item-id)) ERR-ITEM-ALREADY-EXISTS)
        (asserts! (is-valid-item-name name) ERR-INVALID-NAME)
        (asserts! (is-valid-tier tier) ERR-INVALID-TIER)
        (asserts! (<= rarity u10000) ERR-INVALID-RARITY)
        (asserts! (and (> value u0) (<= value MAX-ITEM-VALUE)) ERR-INVALID-VALUE)
        (asserts! (and (> max-supply u0) (<= max-supply MAX-SUPPLY)) ERR-INVALID-SUPPLY)
        
        (map-set loot-items item-id {
            name: name,
            tier: tier,
            rarity: rarity,
            value: value,
            supply: u0,
            max-supply: max-supply
        })
        (ok true)))

;; Update drop rates (admin only)
(define-public (update-drop-rate (tier uint) (item-tier uint) (rate uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-tier tier) ERR-INVALID-TIER)
        (asserts! (is-valid-tier item-tier) ERR-INVALID-TIER)
        (asserts! (<= rate u10000) ERR-INVALID-RATE)
        
        (map-set tier-drop-rates {tier: tier, item-tier: item-tier} rate)
        (ok true)))

;; Pause/unpause contract (admin only)
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok (var-get contract-paused))))

;; Withdraw contract balance (admin only)
(define-public (withdraw-funds (amount uint) (recipient principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-FUNDS)
        (asserts! (is-valid-principal recipient) ERR-INVALID-RECIPIENT)
        
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        (ok true)))

;; Transfer ownership (admin only)
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-principal new-owner) ERR-INVALID-RECIPIENT)
        (var-set contract-owner new-owner)
        (ok true)))

;; Update random seed (admin only)
(define-public (update-random-seed (new-seed uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (and (> new-seed u0) (<= new-seed MAX-SEED)) ERR-INVALID-SEED)
        (var-set random-seed new-seed)
        (ok true)))

;; Read-only functions

(define-read-only (get-loot-box (box-id uint))
    (map-get? loot-boxes box-id))

(define-read-only (get-loot-item (item-id uint))
    (map-get? loot-items item-id))

(define-read-only (get-user-loot-boxes (user principal))
    (map-get? user-loot-boxes user))

(define-read-only (get-user-item-balance (user principal) (item-id uint))
    (default-to u0 (map-get? user-inventory {user: user, item-id: item-id})))

(define-read-only (get-loot-box-price (tier uint))
    (map-get? loot-box-prices tier))

(define-read-only (get-contract-stats)
    {
        total-boxes-sold: (var-get loot-box-counter),
        total-revenue: (var-get total-revenue),
        contract-balance: (stx-get-balance (as-contract tx-sender)),
        is-paused: (var-get contract-paused),
        owner: (var-get contract-owner),
        current-random-seed: (var-get random-seed)
    })

(define-read-only (get-drop-rate (tier uint) (item-tier uint))
    (map-get? tier-drop-rates {tier: tier, item-tier: item-tier}))

(define-read-only (is-box-owner (box-id uint) (user principal))
    (match (map-get? loot-boxes box-id)
        box-data (is-eq (get owner box-data) user)
        false))

(define-read-only (get-item-supply (item-id uint))
    (match (map-get? loot-items item-id)
        item-data (get supply item-data)
        u0))

;; Initialize the contract
(initialize-contract)