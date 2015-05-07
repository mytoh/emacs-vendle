;;; github.el -*- lexical-binding: t -*-

(require 'seq)

(cl-defun vendle:source-site-github-p (source)
  (cond
    ((string-match (rx "github:" (submatch (+ (not (in "/")))
                                           "/"
                                           (+ (not (in "/")))))
                   source)
     t)
    ((string-match (rx   line-start
                         (one-or-more (not (in "/")))
                         "/"
                         (one-or-more (not (in "/")))
                         line-end)
                   source)
     t)
    (t nil)))

(cl-defun vendle:source-site-format-github (source)
  (cond
    ((string-match (rx "github:" (submatch (+ (not (in "/")))
                                           "/"
                                           (+ (not (in "/")))))
                   source)
     (match-string-no-properties 1 source))
    ((string-match (rx   line-start
                         (one-or-more (not (in "/")))
                         "/"
                         (one-or-more (not (in "/")))
                         line-end)
                   source)
     (match-string-no-properties 0 source))))

(cl-defun vendle:make-package-github (source option)
  (cl-letf ((name (vendle:make-package-name-github source option))
            (path (vendle:make-package-path-github source option))
            (lpath (vendle:make-package-load-path-github source option))
            (origin (vendle:make-package-origin-github source option)))
    (make-instance 'vendle:<package>
                   :type 'git
                   :site "github"
                   :name name
                   :path path
                   :load-path lpath
                   :url (seq-concatenate 'string "git@github.com:" source)
                   :compile (cl-getf option :compile t)
                   :dependency (cl-getf option :depends nil)
                   :build (cl-getf option :build nil)
                   :info (cl-getf option :info nil)
                   :origin origin
                   :tag (cl-getf option :tag nil)
                   :desc (cl-getf option :desc "")
                   :recursive (cl-getf option :recursive)
                   :branch (cl-getf option :branch))))

(cl-defun vendle:make-package-name-github (source option)
  (if option
      (cl-letf ((name (cl-getf option :name)))
        (if name
            name
          (cl-second (split-string source "/"))))
    (cl-second (split-string source "/"))))

(cl-defun vendle:make-package-load-path-github (source option)
  (cl-letf ((path (cl-getf option :load-path nil))
            (origin (vendle:make-package-origin-github source option)))
    (if path
        (if (listp path)
            (seq-map
             (lambda (p)
               (vendle:concat-path vendle-directory origin p))
             path)
          (vendle:concat-path vendle-directory origin path))
      (vendle:concat-path vendle-directory origin))))

(cl-defun vendle:make-package-path-github (source option)
  (cl-letf ((path (cl-getf option :path))
            (origin (vendle:make-package-origin-github source option)))
    (if path
        (vendle:concat-path vendle-directory path)
      (vendle:concat-path vendle-directory origin))))

(cl-defun vendle:make-package-origin-github (source option)
  (cl-letf ((origin (cl-getf option :origin nil)))
    (if origin
        origin
      (cond
        ((string-match (rx line-start
                           "github:"
                           (submatch (one-or-more (not (in "/"))))
                           "/"
                           (submatch (one-or-more (not (in "/"))))
                           line-end)
                       source)
         (seq-concatenate 'string
                          "github.com/"
                          (match-string-no-properties 1 source)
                          "/"
                          (match-string-no-properties 2 source)))
        ((string-match (rx   line-start
                             (submatch (one-or-more (not (in "/"))))
                             "/"
                             (submatch (one-or-more (not (in "/"))))
                             line-end)
                       source)
         (seq-concatenate 'string
                          "github.com/"
                          (match-string-no-properties 1 source)
                          "/"
                          (match-string-no-properties 2 source)))))))

(provide 'vendle-source-github)

;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
