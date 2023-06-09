;; args.scm -- Command line argument handling.
;; Copyright (C) 2013, 2016, 2018, 2023 Ludovic Courtès <ludo@gnu.org>
;; Copyright (C) 2002, 2003 Wolfgang Jährling <wolfgang@pro-linux.de>
;;
;; This file is part of the GNU Shepherd.
;;
;; The GNU Shepherd is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3 of the License, or (at
;; your option) any later version.
;;
;; The GNU Shepherd is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with the GNU Shepherd.  If not, see <http://www.gnu.org/licenses/>.

(define-module (shepherd args)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module ((ice-9 control) #:select (call/ec))
  #:use-module (shepherd support)
  #:use-module (shepherd config)
  #:export (option
            option?
            process-args))

;; This does mostly the same as getopt-long, except for that it is
;; able to recognize abbreviations for long options, as long as they
;; are not ambiguous.  Additionally, output is done in a way that makes
;; localization possible.

(define-record-type <option>
  (make-option short long description takes-arg? arg-name
               optional-arg? action)
  option?
  ;; Short name for the option.  A character, or `#f' if no short name.
  (short option-short-name)
  ;; Long name for the option.  A string, or `#f' if no long name.
  (long  option-long-name)
  ;; A string describing the option.
  (description option-description)
  ;; Specifies whether the procedure in the `action' slot takes an
  ;; argument.  If this is the case, it will be called with the
  ;; argument specified on the command line (If there was none
  ;; specified, the procedure will be called with `#f').
  (takes-arg?  option-takes-argument?)
  ;; Name of the argument, if any.
  (arg-name    option-argument-name)
  ;; Whether the arg is optional.
  (optional-arg? option-argument-is-optional?)
  ;; The procedure that will be called when the option is found in the
  ;; argument list.
  (action        option-action))

(define* (option #:key short-name long-name description
                 takes-argument? argument-name
                 argument-is-optional? action)
  "Return a new record for a command-line option with the given
characteristics."
  (make-option short-name long-name
               (or description (l10n "undocumented option"))
               takes-argument?
               (or argument-name (l10n "ARG"))
               argument-is-optional?
               action))

(define (optional-arg? opt)
  (and (option-takes-argument? opt)
       (option-argument-is-optional? opt)))

(define (long-option-string opt)
  (assert (option-long-name opt))
  (string-append "--"
		 (option-long-name opt)
		 (if (optional-arg? opt) "[" "")
		 (if (option-takes-argument? opt)
		     (string-append "=" (option-argument-name opt))
		     "")
		 (if (optional-arg? opt) "]" "")))

(define (display-doc opt)
  (let ((col 0))
    (define (output text)
      (set! col (+ col (string-length text)))
      (display text))
    (define (fill-to target-col)
      (while (< col target-col)
	     (output (string #\space))))

    (fill-to 2)
    (when (option-short-name opt)
      (output (string #\- (option-short-name opt) #\,)))
    (fill-to 6)
    (when (option-long-name opt)
      (output (long-option-string opt)))
    (fill-to 30)
    (output (option-description opt)))
  (newline))

;; Interpret command line arguments ARGS according to OPTIONS, passing
;; non-option arguments to DEFAULT.  Uses `program-name' and
;; `bug-address', which must be defined elsewhere.
(define (process-args program-name args args-syntax args-desc
                      default . options)
  ;; If this returns `#f', it means no option that can be abbreviated
  ;; as NAME (or has exactly this name) was found.  If the return
  ;; value is an option, it is exactly that or an abbreviation for it.
  ;; `#t' means that it is ambiguous.
  (define (find-long-option name)
    (call/ec (lambda (return)
	       (let ((abbrev-for #f))
		 (for-each (lambda (option)
			     ;; Matches exactly.
			     (and (string=? name (option-long-name option))
				  (return option))
			     ;; Abbreviation.
			     (and (string-prefix? name (option-long-name option))
				  (if abbrev-for
				      (set! abbrev-for #t)
				    (set! abbrev-for option))))
			   options)
		 abbrev-for))))

  ;; Return the option, or `#f' if none found.
  (define (find-short-option char)
    (find (lambda (option)
            (equal? char (option-short-name option)))
          options))

  ;; Interpret ARG as non-option argument.
  (define (no-option arg)
    (or (default arg)
	((option-action (find-long-option "help")))))

  ;; Add a few standard options first.
  (set! options
	(cons* (option
		 #:long-name "version"
		 #:description (l10n "display version information and exit")
		 #:action (lambda ()
			    (display-version program-name)
			    (quit)))
	       (option
		 #:long-name "usage"
		 #:description (l10n "display short usage message and exit")
		 #:action (lambda ()
			    (display program-name)
			    (display " ")

			    ;; Short options first.
			    (let ((no-arg "[-") (with-arg ""))
			      (define (add-text opt)
				(and (option-short-name opt)
				     (if (option-takes-argument? opt)
					 (let ((opt-arg? (optional-arg? opt)))
					   (set! with-arg
						 (string-append
						  with-arg
						  " [-"
						  (string (option-short-name opt))
						  " "
						  (if opt-arg? "[" "")
						  (option-argument-name opt)
						  (if opt-arg? "]" "")
						  "]")))
				       (set! no-arg
					     (string-append
					      no-arg
					      (string (option-short-name opt)))))))
			      (for-each add-text options)
			      (set! no-arg (string-append no-arg "]"))
			      (display no-arg)
			      (display with-arg))

			    ;; Long options.
			    (for-each
			     (lambda (opt)
			       (and (option-long-name opt)
				    (display (string-append
					      " ["
					      (long-option-string opt)
					      "]"))))
			     (cdddr options)) ;; Skip the first three.

			    ;; Non-option arguments.
			    (display " [--] ")
			    (display args-syntax)
			    (newline)
			    (quit)))
	       (option
		 #:long-name "help"
		 #:description (l10n "display this help and exit")
		 #:action (lambda ()
			    (for-each display
				      (list program-name
					    (l10n " [OPTIONS...] ")
					    args-syntax))
			    (newline)
			    (display args-desc)
			    (newline)
			    (for-each display-doc (reverse! options))

                            ;; TRANSLATORS: The '~a' placeholders indicate the
                            ;; bug-reporting address, the name of this
                            ;; package, and its home page URL.  Please add
                            ;; another line saying "Report translation bugs to
                            ;; ...\n" with the address for translation bugs
                            ;; (typically your translation team's web or email
                            ;; address).
			    (format #t (l10n "
Mandatory or optional arguments to long options are also mandatory or
optional to the corresponding short options.

Report bugs to: ~a .
~a general home page: <~a>
General help using GNU software: <http://www.gnu.org/gethelp/>~%")
                                    bug-address
                                    package-name
                                    package-url)
			    (quit)))
	       options))
  (let next-arg ((ptr args))
    (and (not (null? ptr))
	 (let ((arg (car ptr)))
	   ;; Call the procedure for OPTION (with the PARAM, if
	   ;; desired).
	   (define (apply-option option param)
	     (apply (option-action option)
		    (if (option-takes-argument? option)
			(cons param '())
		        '())))

	   (cond
	    ;; Long option.
	    ((string-prefix? "--" arg)
	     (if (string=? arg "--")
		 ;; Don't interpret further arguments as options.
		 (begin
		   (for-each no-option (cdr ptr))
		   (set! ptr (cons #f '())))
	       ;; Normal case.
	       (let* ((name (string-drop arg 2))
		      (index (string-index name #\=))
		      (param #f)
		      (target-option #f))
		 (and index
		      (begin
			;; It is of the form `--option=parameter'.
			(set! param (string-drop name (1+ index)))
			(set! name (string-take name index))))
		 ;; Find the right one (as it might be abbreviated).
		 (set! target-option (find-long-option name))
		 (and (boolean? target-option)
		      (begin
			(local-output
			 (if target-option
			     (l10n "Option `--~a' is ambiguous.")
			   (l10n "Unknown option: `--~a'."))
			 name)
			(local-output (l10n "Try `--help'."))
			(quit 1)))
		 (and (option-takes-argument? target-option)
		      (not (optional-arg? target-option))
		      (not param)
		      (not (null? (cdr ptr)))
		      (or (not (string-prefix? "-" (cadr ptr)))
			  (string=? "-" (cadr ptr)))
		      (begin
			;; If we reach this point, it means that we
			;; need a parameter, we have none, there is
			;; another argument and it does not look like
			;; an option.  In this case, we obviously use
			;; that as parameter.
			(set! ptr (cdr ptr))
			(set! param (car ptr))))
		 (apply-option target-option param))))
	    ;; Short option.
	    ((string-prefix? "-" arg)
	     (let* ((opt-char (string-ref arg 1))
		    (target-option (find-short-option opt-char))
		    (param #f))
	       (if (not target-option)
		   (begin
		     (local-output (l10n "Unknown option: `-~a'.")
                                   opt-char)
		     (quit 1))
		 (if (option-takes-argument? target-option)
		     (begin
		       (if (= (string-length arg) 2)
			   ;; Take next argument as param.
			   (if (or (null? (cdr ptr))
				   (and (string-prefix? "-" (cadr ptr))
					(not (string=? "-" (cadr ptr)))))
			       (or (optional-arg? target-option)
				   (begin
				     (local-output
				      (l10n "Argument required by `-~a'.")
                                      opt-char)
				     (quit 1)))
			     (begin
			       (set! ptr (cdr ptr))
			       (set! param (car ptr))))
			 ;; Parameter is the rest of this argument.
			 (set! param (string-drop arg 2)))
		       (apply-option target-option param))
		   ;; Does not take a parameter, thus the
		   ;; following chars are also options without
		   ;; parameter.
		   (for-each (lambda (c)
			       (apply-option (find-short-option c) #f))
			     (string->list (string-drop arg 1)))))))
	    ;; Not interpreted as option.
	    (else
	     (no-option arg)))
	   (next-arg (cdr ptr))))))

