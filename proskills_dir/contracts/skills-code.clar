;; Skills Marketplace Smart Contract 
;; Basic implementation with core listing and booking functionality

;; Constants
(define-constant contract-administrator tx-sender)
(define-constant ERROR_NOT_CONTRACT_OWNER (err u100))
(define-constant ERROR_SERVICE_LISTING_NOT_FOUND (err u101))
(define-constant ERROR_INVALID_SERVICE_PRICE (err u102))

;; Data structures
(define-map service-listings 
    { listing-id: uint }
    {
        provider-address: principal,
        service-price: uint,
        service-description: (string-ascii 256),
        expertise-category: (string-ascii 64),
        is-available: bool
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

;; Variables
(define-data-var next-listing-id uint u1)
(define-data-var platform-fee-rate uint u2) ;; 2% platform fee

;; Private functions
(define-private (calculate-platform-fee (service-price uint))
    (/ (* service-price (var-get platform-fee-rate)) u100)
)

(define-private (execute-stx-transfer (from-address principal) (to-address principal) (payment-amount uint))
    (stx-transfer? payment-amount from-address to-address)
)

;; Public functions
(define-public (create-service-listing (service-price uint) 
                                     (service-description (string-ascii 256)) 
                                     (expertise-category (string-ascii 64)))
    (let
        (
            (current-listing-id (var-get next-listing-id))
        )
        (asserts! (> service-price u0) ERROR_INVALID_SERVICE_PRICE)
        
        (map-set service-listings
            { listing-id: current-listing-id }
            {
                provider-address: tx-sender,
                service-price: service-price,
                service-description: service-description,
                expertise-category: expertise-category,
                is-available: true
            }
        )
        
        (var-set next-listing-id (+ current-listing-id u1))
        (ok current-listing-id)
    )
)

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
        (asserts! (get is-available listing-details) ERROR_SERVICE_LISTING_NOT_FOUND)
        
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
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-service-details (listing-id uint))
    (map-get? service-listings { listing-id: listing-id })
)

(define-read-only (get-current-platform-fee)
    (var-get platform-fee-rate)
)