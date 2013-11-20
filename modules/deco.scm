;; deco.scm -- The `DaEmon COntrol' program.
;; Copyright (C) 2013 Ludovic Court�s <ludo@gnu.org>
;; Copyright (C) 2002, 2003 Wolfgang J�hrling <wolfgang@pro-linux.de>
;;
;; This file is part of GNU dmd.
;;
;; GNU dmd is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3 of the License, or (at
;; your option) any later version.
;;
;; GNU dmd is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU dmd.  If not, see <http://www.gnu.org/licenses/>.

(define-module (deco)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (dmd config)
  #:use-module (dmd support)
  #:use-module (dmd args)
  #:use-module (dmd comm)
  #:export (program-name
            main))

(define program-name "deco")



;; Main program.
(define (main args)
  (false-if-exception (setlocale LC_ALL ""))

  (let ((socket-file default-socket-file)
	(deco-socket-file default-deco-socket-file)
	(command-args '()))
    (process-args program-name args
		  "ACTION SERVICE [ARG...]"
		  (string-append
		   "Apply ACTION (start, stop, status, etc.) on SERVICE"
		   " with the ARGs.")
		  (lambda (arg)
		    ;; Collect unknown args.
		    (set! command-args (cons arg command-args)))
		  (make <option>
		    ;; It might actually be desirable to have an
		    ;; ``insecure'' setup in some circumstances, thus
		    ;; we provide it as an option.
		    #:long "insecure" #:short #\I
		    #:takes-arg? #f
		    #:description "don't ensure that the setup is secure"
		    #:action (lambda ()
			       (set! insecure? #t)))
		  (make <option>
		    #:long "socket" #:short #\s
		    #:takes-arg? #t #:optional-arg? #f #:arg-name "FILE"
		    #:description "send commands to FILE"
		    #:action (lambda (file)
			       (set! socket-file file)))
		  (make <option>
		    #:long "result-socket" #:short #\r
		    #:takes-arg? #t #:optional-arg? #f #:arg-name "FILE"
		    #:description "use FILE to receive responses"
		    #:action (lambda (file)
			       (set! deco-socket-file file))))

    ;; Make sure we got at least two arguments.
    (when (< (length command-args) 2)
      (format (current-error-port)
              (l10n "Usage: deco ACTION SERVICE OPTIONS...~%"))
      (exit 1))

    (set! command-args (reverse command-args))
    (let ((sender (make <sender> socket-file))
	  (receiver (make <receiver> deco-socket-file)))
      ;; Send initial handshake.
      (send-data sender (number->string (+ 2 (length command-args))))
      (send-data sender (getcwd))
      (send-data sender deco-socket-file)
      ;; Send the command.
      (for-each (lambda (arg)
		  (send-data sender arg))
		command-args)
      ;; Receive output.
      (letrec ((next-line (lambda (line)
			    (if (string=? line terminating-string)
				(quit)
			      (begin
				(display line)
				(next-line (receive-data receiver)))))))
	(next-line (receive-data receiver))))))

(main (cdr (command-line)))