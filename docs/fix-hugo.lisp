;;; -*- Mode: LISP; Package: :cl-user; BASE: 10; Syntax: ANSI-Common-Lisp; -*-
;;;
;;;   Time-stamp: <>
;;;   Touched: Tue Feb 07 22:49:28 2023 +0530 <enometh@net.meer>
;;;   Bugs-To: enometh@net.meer
;;;   Status: Experimental.  Do not redistribute
;;;   Copyright (C) 2023 Madhu.  All Rights Reserved.
;;;
;;; rewrite links in the files generated by hugo to point to relative
;;; locations so they can be browsed locally.  based on a vbscript
;;; posted in https://github.com/gohugoio/hugo/issues/4642
;;;
;;; Adjust $BADPATH to point to baseURL in config.toml set $PWD,
;;; $DOC-ROOT. $DOC-ROOT is relative to $PWD and is where the `public'
;;; generated files are.  Run hugo in $DOC-ROOT, generate a sequence
;;; of paths of files to modify (viz. `find $doc-root -name \*.html')
;;; and pass this sequence to DOREPLACE-FILES.


(in-package "CL-USER")
(require 'cl-ppcre)
(defpackage "FIX-HUGO" (:use "CL"))
(in-package "FIX-HUGO")

(defun get-level (base path)
  (let ((pos (search base path)))
    (assert (zerop pos))
    (let ((parts (user::string-split-map #(#\/) (subseq path (length base)))))
      (1- (length parts)))))

#+nil
(equal (get-level "docs/public/" "docs/public/semaphores/semaphore/index.html")
       2)
#+nil
(equal (get-level "docs/public/" "docs/public/index.html")
       0)

(defun get-level-string (n)
  (with-output-to-string (stream)
    (loop repeat n do (write-string "../" stream))))

#+nil
(equal (get-level-string 2)  "../../")

(defun is-file (string &key (start 0) (end (length string)))
  "is STRING a filename with an extension"
  (and (cl-ppcre:scan ".*\\.[a-zA-Z]{2,4}$" string :start start :end end) t))

#+nil
(equal (is-file "foo") nil)

#+nil
(equal (is-file "foo.bar") t)


;;; ----------------------------------------------------------------------
;;;
;;;
;;;

(defvar $pwd "/home/madhu/cl/extern/bordeaux-threads/")

(defvar $doc-root "docs/public/"
  "relative to pwd, where the hugo sources reside.")

(defvar $badpath "https://sionescu.github.io/bordeaux-threads/"
  "baseURL from config.toml. (with relativeURLS = uglyURLS = false) ")

(defvar *level* nil)

;; handle urls rooted at badpath
(defvar $scanner0
  (cl-ppcre:create-scanner (concatenate 'string $badpath "(.*?)\"")))

(defun replacer0 (target-string start end match-start match-end reg-starts reg-ends)
  (declare (ignorable start end match-start match-end))
  (concatenate 'string
	       (get-level-string *level*)
	       (subseq target-string (elt reg-starts 0) (elt reg-ends 0))
	       (if (is-file target-string :start (elt reg-starts 0)
			    :end (elt reg-ends 0))
		   ""
		   (if (eql (char target-string (- (elt reg-ends 0) 1)) #\/)
		       "index.html"
		       "/index.html"))
	       "\""))

#||
(setq $a "https://sionescu.github.io/bordeaux-threads/index.html\""
(cl-ppcre:scan $scanner0 $a)
(let ((*level* 0))
  (cl-ppcre:regex-replace $scanner0 $a #'replacer0)))
||#

;; handle home page references
(defvar $scanner1 (cl-ppcre:create-scanner (concatenate 'string
							"href=\""
							$badpath)))

(defun replacer1 (target-string start end match-start match-end reg-starts reg-ends)
  (declare (ignorable target-string start end match-start match-end reg-starts reg-ends))
  (concatenate 'string "href=\"" (get-level-string *level*) "index.html"))


;; handle relative urls of depth 1 that point to a directory
(defvar $scanner2 (cl-ppcre:create-scanner "href=\"([^/\"]+)\""))

(defun replacer2 (target-string start end match-start match-end reg-starts reg-ends)
  (declare (ignorable target-string start end  match-start match-end reg-starts reg-ends))
  (concatenate 'string "href=\"" (subseq target-string (elt reg-starts 0) (elt reg-ends 0)) "/index.html\""))

#+nil
(equal (cl-ppcre:regex-replace $scanner2  "href=\"foo\"" #'replacer2)
       "href=\"foo/index.html\"")

(defun doreplace-string (string *level*)
  (let* ((pass1 (cl-ppcre:regex-replace-all $scanner0 string #'replacer0))
	 (pass2 (cl-ppcre:regex-replace-all $scanner1 pass1 #'replacer1))
	 (pass3 (cl-ppcre:regex-replace-all $scanner2 pass2 #'replacer2)))
    pass3))

(defun doreplace-file (pathname *level* &key function)
  (let* ((string (cl-user:slurp-file pathname nil :element-type 'character))
	 (new-string (if function
			 (funcall function string *level*)
			 (doreplace-string string *level*))))
    (cl-user::string->file new-string pathname)))

(defun doreplace-files (files &key function)
  (map nil (lambda (rel-path)
	     (let* ((file-path (concatenate 'string $pwd rel-path))
		    (level (get-level $doc-root rel-path)))
	       (doreplace-file file-path level :function function)))
       files))

(defun make-file-list ()
  (cl-user:in-directory $pwd
    (cl-user:with-open-pipe (stream (format nil "find ~a -type f -name \*.html"
					    $doc-root))
      (cl-user:read-lines-from-stream stream))))

#+nil
(doreplace-files (make-file-list))
