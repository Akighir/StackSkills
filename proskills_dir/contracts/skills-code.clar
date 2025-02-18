;; Skills Marketplace Smart Contract
;; Allows professionals to list, sell, and manage their services on the Stacks blockchain

;; Constants
(define-constant contract-administrator tx-sender)
(define-constant ERROR_NOT_CONTRACT_OWNER (err u100))
(define-constant ERROR_SERVICE_LISTING_NOT_FOUND (err u101))
(define-constant ERROR_SERVICE_ALREADY_EXISTS (err u102))
(define-constant ERROR_CLIENT_INSUFFICIENT_BALANCE (err u103))
(define-constant ERROR_UNAUTHORIZED_CLIENT (err u104))
(define-constant ERROR_INVALID_SERVICE_PRICE (err u105))
(define-constant ERROR_INVALID_PARAMETER (err u106))

;; Data structures
(define-map service-listings 
    { listing-id: uint }
    {
        provider-address: principal,
        service-price: uint,
        service-description: (string-ascii 256),
        expertise-category: (string-ascii 64),
        is-available: bool,
        posted-timestamp: uint
    }
)

(define-map user-marketplace-stats
    { marketplace-participant: principal }
    {
        completed-services-count: uint,
        provider-rating: uint,
        last-activity-time: uint
    }
)

(define-map completed-bookings
    { client-address: principal, booked-listing-id: uint }
    {
        booking-timestamp: uint,
        payment-amount: uint,
        provider-address: principal
    }
)

;; Storage of service credentials (encrypted off-chain)
(define-map service-credentials
    { listing-id: uint }
    { encrypted-access-details: (string-ascii 512) }
)

;; Variables
(define-data-var next-listing-id uint u1)
(define-data-var platform-fee-rate uint u2) ;; 2% platform fee
(define-data-var total-completed-bookings uint u0)

;; Input validation functions
(define-private (validate-description-length (description-text (string-ascii 256)))
    (and 
        (not (is-eq description-text ""))
        (<= (len description-text) u256)
    )
)

(define-private (validate-category-length (category-text (string-ascii 64)))
    (and
        (not (is-eq category-text ""))
        (<= (len category-text) u64)
    )
)

(define-private (validate-credentials-length (credentials (string-ascii 512)))
    (and
        (not (is-eq credentials ""))
        (<= (len credentials) u512)
    )
)

;; Private functions
(define-private (calculate-platform-fee (service-price uint))
    (/ (* service-price (var-get platform-fee-rate)) u100)
)

(define-private (execute-stx-transfer (from-address principal) (to-address principal) (payment-amount uint))
    (stx-transfer? payment-amount from-address to-address)
)

;; Public functions

;; List a new service
(define-public (create-service-listing (service-price uint) 
                                     (service-description (string-ascii 256)) 
                                     (expertise-category (string-ascii 64)) 
                                     (encrypted-access-details (string-ascii 512)))
    (let
        (
            (current-listing-id (var-get next-listing-id))
        )
        ;; Input validation
        (asserts! (> service-price u0) ERROR_INVALID_SERVICE_PRICE)
        (asserts! (validate-description-length service-description) ERROR_INVALID_PARAMETER)
        (asserts! (validate-category-length expertise-category) ERROR_INVALID_PARAMETER)
        (asserts! (validate-credentials-length encrypted-access-details) ERROR_INVALID_PARAMETER)
        (asserts! (not (default-to false (get is-available 
            (map-get? service-listings { listing-id: current-listing-id })))) 
            ERROR_SERVICE_ALREADY_EXISTS)
        
        (map-set service-listings
            { listing-id: current-listing-id }
            {
                provider-address: tx-sender,
                service-price: service-price,
                service-description: service-description,
                expertise-category: expertise-category,
                is-available: true,
                posted-timestamp: block-height
            }
        )
        
        (map-set service-credentials
            { listing-id: current-listing-id }
            { encrypted-access-details: encrypted-access-details }
        )
        
        (var-set next-listing-id (+ current-listing-id u1))
        (ok current-listing-id)
    )
)

;; Book a service
(define-public (book-service (listing-id uint))
    (let
        (
            (listing-details (unwrap! (map-get? service-listings { listing-id: listing-id }) 
                ERROR_SERVICE_LISTING_NOT_FOUND))
            (total-price (get service-price listing-details))
            (service-provider (get provider-address listing-details))
            (platform-fee (calculate-platform-fee total-price))
            (provider-payment (- total-price platform-fee))
        )
        ;; Input validation
        (asserts! (< listing-id (var-get next-listing-id)) ERROR_INVALID_PARAMETER)
        (asserts! (get is-available listing-details) ERROR_SERVICE_LISTING_NOT_FOUND)
        (asserts! (is-eq false (is-eq tx-sender service-provider)) ERROR_UNAUTHORIZED_CLIENT)
        
        ;; Process payments
        (try! (execute-stx-transfer tx-sender service-provider provider-payment))
        (try! (execute-stx-transfer tx-sender contract-administrator platform-fee))
        
        ;; Record booking
        (map-set completed-bookings
            { client-address: tx-sender, booked-listing-id: listing-id }
            {
                booking-timestamp: block-height,
                payment-amount: total-price,
                provider-address: service-provider
            }
        )
        
        ;; Update provider stats
        (let
            (
                (provider-profile (default-to 
                    { completed-services-count: u0, provider-rating: u0, last-activity-time: u0 }
                    (map-get? user-marketplace-stats { marketplace-participant: service-provider })))
            )
            (map-set user-marketplace-stats
                { marketplace-participant: service-provider }
                {
                    completed-services-count: (+ (get completed-services-count provider-profile) u1),
                    provider-rating: (get provider-rating provider-profile),
                    last-activity-time: block-height
                }
            )
        )
        
        (var-set total-completed-bookings (+ (var-get total-completed-bookings) u1))
        (ok true)
    )
)

;; Get service access details (only available to client)
(define-public (get-service-credentials (listing-id uint))
    (let
        (
            (booking-record (unwrap! (map-get? completed-bookings 
                { client-address: tx-sender, booked-listing-id: listing-id }) ERROR_UNAUTHORIZED_CLIENT))
            (service-access-details (unwrap! (map-get? service-credentials 
                { listing-id: listing-id }) ERROR_SERVICE_LISTING_NOT_FOUND))
        )
        ;; Input validation
        (asserts! (< listing-id (var-get next-listing-id)) ERROR_INVALID_PARAMETER)
        (ok (get encrypted-access-details service-access-details))
    )
)

;; Update service price
(define-public (update-service-price (listing-id uint) (new-price uint))
    (let
        (
            (listing-details (unwrap! (map-get? service-listings { listing-id: listing-id }) 
                ERROR_SERVICE_LISTING_NOT_FOUND))
        )
        ;; Input validation
        (asserts! (< listing-id (var-get next-listing-id)) ERROR_INVALID_PARAMETER)
        (asserts! (is-eq (get provider-address listing-details) tx-sender) ERROR_NOT_CONTRACT_OWNER)
        (asserts! (> new-price u0) ERROR_INVALID_SERVICE_PRICE)
        
        (map-set service-listings
            { listing-id: listing-id }
            (merge listing-details { service-price: new-price })
        )
        (ok true)
    )
)

;; Remove service listing
(define-public (deactivate-service (listing-id uint))
    (let
        (
            (listing-details (unwrap! (map-get? service-listings { listing-id: listing-id }) 
                ERROR_SERVICE_LISTING_NOT_FOUND))
        )
        ;; Input validation
        (asserts! (< listing-id (var-get next-listing-id)) ERROR_INVALID_PARAMETER)
        (asserts! (is-eq (get provider-address listing-details) tx-sender) ERROR_NOT_CONTRACT_OWNER)
        
        (map-set service-listings
            { listing-id: listing-id }
            (merge listing-details { is-available: false })
        )
        (ok true)
    )
)

;; Admin functions
(define-public (update-platform-fee (new-fee-percentage uint))
    (begin
        (asserts! (is-eq tx-sender contract-administrator) ERROR_NOT_CONTRACT_OWNER)
        (asserts! (<= new-fee-percentage u100) ERROR_INVALID_SERVICE_PRICE)
        (var-set platform-fee-rate new-fee-percentage)
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-service-details (listing-id uint))
    (map-get? service-listings { listing-id: listing-id })
)

(define-read-only (get-provider-profile (marketplace-participant principal))
    (map-get? user-marketplace-stats { marketplace-participant: marketplace-participant })
)

(define-read-only (get-total-completed-bookings)
    (var-get total-completed-bookings)
)

(define-read-only (get-current-platform-fee)
    (var-get platform-fee-rate)
)