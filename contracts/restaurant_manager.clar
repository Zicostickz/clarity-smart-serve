;; SmartServe Restaurant Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-reservation (err u101))
(define-constant err-table-occupied (err u102))
(define-constant err-insufficient-points (err u103))
(define-constant err-invalid-menu-item (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-invalid-table (err u106))
(define-constant err-reservation-expired (err u107))
(define-constant err-invalid-time (err u108))
(define-constant err-maintenance-required (err u109))

;; Data Variables
(define-data-var loyalty-rate uint u10)
(define-data-var points-redemption-rate uint u100)
(define-data-var maintenance-interval uint u48) ;; Hours between required cleaning

(define-map Reservations
  { reservation-id: uint }
  {
    customer: principal,
    table-number: uint,
    time-slot: uint,
    end-time: uint,
    guests: uint,
    status: (string-ascii 20)
  }
)

(define-map Tables
  { table-number: uint }
  { 
    capacity: uint, 
    is-occupied: bool,
    last-cleaned: uint,
    maintenance-history: (list 10 uint),
    reservation-end-time: uint
  }
)

;; Private Functions
(define-private (is-valid-reservation (table-number uint) (time-slot uint))
  (let (
    (table-info (default-to { 
      capacity: u0, 
      is-occupied: true, 
      last-cleaned: u0,
      maintenance-history: (list),
      reservation-end-time: u0 
    } (map-get? Tables { table-number: table-number })))
    (current-time block-height)
  )
    (and 
      (not (get is-occupied table-info))
      (> (get capacity table-info) u0)
      (>= (- (get last-cleaned table-info) current-time) (var-get maintenance-interval))
      (> time-slot current-time)
    )
  )
)

(define-private (update-maintenance-history (table-number uint) (current-time uint))
  (let (
    (table-info (unwrap! (map-get? Tables { table-number: table-number }) err-invalid-table))
    (history (get maintenance-history table-info))
  )
    (ok (as-max-len? (append history current-time) u10))
  )
)

;; Public Functions
(define-public (make-reservation (reservation-id uint) (table-number uint) (time-slot uint) (duration uint) (guests uint))
  (let (
    (is-valid (is-valid-reservation table-number time-slot))
    (end-time (+ time-slot duration))
  )
    (if is-valid
      (begin
        (map-set Reservations
          { reservation-id: reservation-id }
          {
            customer: tx-sender,
            table-number: table-number,
            time-slot: time-slot,
            end-time: end-time,
            guests: guests,
            status: "confirmed"
          }
        )
        (map-set Tables
          { table-number: table-number }
          { 
            capacity: (unwrap! (get capacity (map-get? Tables { table-number: table-number })) err-invalid-table),
            is-occupied: true,
            last-cleaned: (unwrap! (get last-cleaned (map-get? Tables { table-number: table-number })) err-invalid-table),
            maintenance-history: (unwrap! (get maintenance-history (map-get? Tables { table-number: table-number })) err-invalid-table),
            reservation-end-time: end-time
          }
        )
        (ok true)
      )
      err-invalid-reservation
    )
  )
)

(define-public (update-table-status (table-number uint) (is-clean bool))
  (if (is-eq tx-sender contract-owner)
    (let (
      (table (unwrap! (map-get? Tables { table-number: table-number }) err-invalid-table))
      (current-time block-height)
      (maintenance-record (unwrap! (update-maintenance-history table-number current-time) err-invalid-table))
    )
      (map-set Tables
        { table-number: table-number }
        (merge table { 
          is-occupied: false,
          last-cleaned: (if is-clean current-time u0),
          maintenance-history: maintenance-record
        })
      )
      (ok true)
    )
    err-owner-only
  )
)
