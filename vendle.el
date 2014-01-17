;;; vendle.el -*- lexical-binding: t -*-

;;; requirements
(eval-when-compile
  (require 'cl-lib))

;;; internal functions

(cl-defun vendle:source-git-p (source)
  (cond ((or (string-match (rx "git://") source)
             (string-match (rx ".git" (zero-or-one "/") line-end) source))
         t)
        (t nil)))

(cl-defun vendle:source-github-p (source)
  (cond ((string-match (rx "github:" (submatch (+ (or (syntax word) (syntax symbol)))
                                               "/"
                                               (+ (or (syntax word) (syntax symbol)))))
                       source)
         t)
        ((string-match (rx   line-start
                             (one-or-more (or (syntax symbol) (syntax word)))
                             "/"
                             (one-or-more (or (syntax symbol)
                                              (syntax word)))
                             line-end)
                       source)
         t)
        (t nil)))

(cl-defun vendle:source-format-github (source)
  (cond
   ((string-match (rx "github:" (submatch (+ (or (syntax word) (syntax symbol)))
                                          "/"
                                          (+ (or (syntax word) (syntax symbol)))))
                  source)
    (match-string-no-properties 1 source))
   ((string-match (rx   line-start
                        (one-or-more (or (syntax symbol) (syntax word)))
                        "/"
                        (one-or-more (or (syntax symbol)
                                         (syntax word)))
                        line-end)
                  source)
    (match-string-no-properties 0 source))))


(cl-defun vendle:directory-git-p (p)
  (if (file-directory-p (expand-file-name ".git" p))
      t nil))

(cl-defun vendle:add-to-load-path (path)
  (add-to-list 'load-path path))

(cl-defun vendle:add-to-theme-path (path)
  (add-to-list 'custom-theme-load-path path))

(cl-defun vendle:add-to-package-list (path)
  (add-to-list '*vendle-package-list* path))

;;; utilily functions

(cl-defun vendle:concat-path (&rest parts)
  (cl-reduce (lambda (a b) (expand-file-name b a)) parts))

;;;; initialize

(defvar *vendle-directory* "")
(defvar *vendle-package-list* '())

(cl-defun vendle:initialize (&optional path)
  (setq *vendle-package-list* nil)
  (if path
      (setq *vendle-directory* path)
    (setq *vendle-directory*
          (expand-file-name (file-name-as-directory "vendle") user-emacs-directory)))
  (unless (file-exists-p *vendle-directory*)
    (make-directory *vendle-directory*))
  *vendle-directory*)


;;;; update

(cl-defun vendle:update-packages ()
  (when (file-exists-p *vendle-directory*)
    (cl-mapc
     'vendle:update-package
     *vendle-package-list*)))

(cl-defun vendle:update-package (package)
  (cl-letf ((path (vendle:concat-path *vendle-directory* (vendle:package-name package))))
    (when (and (or (cl-equalp 'git (vendle:package-type package))
                   (cl-equalp 'github (vendle:package-type package)))
               (not (file-symlink-p path)))
      (progn
        (cd-absolute path)
        (message "vendle: updating vendle package %s.." path)
        (shell-command "git pull")
        (cd-absolute user-emacs-directory)
        (byte-recompile-directory path 0)
        (message "vendle: updating vendle package %s.. done" path)))))

;;;; install

(cl-defun vendle:install-packages ()
  (cl-mapc
   (lambda (package)
     (vendle:install-package package))
   *vendle-package-list*))

(cl-defun vendle:install-package (package)
  (unless (or (cl-equalp 'local (vendle:package-type package))
              (file-exists-p (vendle:package-path package)))
    (cond ((cl-equalp 'github (vendle:package-type package))
           (vendle:install-package-github package)))))

(cl-defun vendle:install-package-github (package)
  (message "vendle: installing package %s" (vendle:package-name package))
  (shell-command (concat  "git clone " (vendle:package-url package) " "
                          (vendle:concat-path *vendle-directory* (vendle:package-name package)))
                 *vendle-directory*)
  (byte-recompile-directory (vendle:package-path package)  0))


;;;; register
(cl-defun vendle:register (source &optional info)
  (cl-letf* ((package (vendle:make-package source info)))
    (vendle:add-to-load-path
     (vendle:package-path package))
    (vendle:add-to-package-list package)))

(cl-defun vendle:register-local (source &optional info)
  (cl-letf* ((path (expand-file-name source))
             (package (vendle:make-package-local path info)))
    (vendle:add-to-load-path
     (vendle:package-path package))
    (vendle:add-to-package-list package)))

(cl-defun vendle:register-theme (source &optional info)
  (cl-letf* ((package (vendle:make-package source info)))
    (vendle:add-to-theme-path
     (vendle:package-path package))
    (vendle:add-to-package-list package)))

(cl-defun vendle:register-theme-local (source &optional info)
  (cl-letf* ((path (expand-file-name source))
             (package (vendle:make-package-local path info)))
    (vendle:add-to-theme-path
     (vendle:package-path package))
    (vendle:add-to-package-list package)))

;;;; clean
(cl-defun vendle:clean-packages ()
  (cl-letf ((paths (cl-remove-if
                    (lambda (d)
                      (if (cl-member-if
                           (lambda (p)
                             (and (not (cl-equalp 'local (vendle:package-type p)))
                                  (cl-equalp d (expand-file-name (vendle:package-name p)
                                                                 *vendle-directory*))))
                           *vendle-package-list*)
                          t nil))
                    (directory-files *vendle-directory*  'absolute (rx (not (any ".")))))))
    (cl-mapc (lambda (p) (delete-directory p t))
             paths)))

;;;; package

(cl-defstruct vendle:package
  type name url path)

(cl-defun vendle:make-package (source info)
  (cond ((vendle:source-github-p source)
         (vendle:make-package-github
          (vendle:source-format-github source) info))))

(cl-defun vendle:make-package-github (source info)
  (make-vendle:package :type 'github
                       :name (vendle:make-package-name source info)
                       :path (vendle:make-package-path source info)
                       :url (cl-concatenate 'string "git://github.com/" source)))

(cl-defun vendle:make-package-local (source info)
  (make-vendle:package :type 'local
                       :name (vendle:make-package-name-local source info)
                       :path source
                       :url (vendle:make-package-url-local source info)))

(cl-defun vendle:make-package-name (source info)
  (cond ((vendle:source-github-p source)
         (vendle:make-package-name-github
          (vendle:source-format-github source) info))))

(cl-defun vendle:make-package-name-github (source info)
  (if info
      (cl-letf ((name (cl-getf info :name)))
        (if name
            name
          (cadr (split-string source "/"))))
    (cadr (split-string source "/"))))

(cl-defun vendle:make-package-name-local (source info)
  (if info
      (cl-letf ((name (cl-getf info :name)))
        (if name
            name
          (file-name-nondirectory source)))
    (file-name-nondirectory source)))

(cl-defun vendle:make-package-path (source info)
  (cond ((vendle:source-github-p source)
         (vendle:make-package-path-github (vendle:source-format-github source) info))))

(cl-defun vendle:make-package-path-github (source info)
  (cl-letf ((path (if info
                      (cl-letf ((path (cl-getf info :path))
                                (name (vendle:make-package-name source info)))
                        (if path
                            (cl-concatenate 'string
                                            name  "/"  path)
                          name))
                    (vendle:make-package-name source info))))
    (expand-file-name path *vendle-directory*)))

(cl-defun vendle:make-package-url-local (source info)
  (if info
      (cl-letf ((url (cl-getf info :url)))
        (if url
            url
          nil))
    nil))

;; commands
(cl-defun vendle-install ()
  "Install packages using `vendle:install-packages'"
  (interactive)
  (vendle:install-packages))

(cl-defun vendle-update ()
  (interactive)
  (vendle:update-packages)
  (message "vendle: package update finished."))

(cl-defun vendle-clean ()
  (interactive)
  (vendle:clean-packages))

;; font-lock
(cl-defun vendle:turn-on-font-lock ()
  (cl-flet ((add-keywords (face-name keyword-rules)
                          (cl-letf* ((keyword-list (cl-mapcar (lambda (x)
                                                                (symbol-name (cdr x)))
                                                              keyword-rules))
                                     (keyword-regexp (concat "(\\("
                                                             (regexp-opt keyword-list)
                                                             "\\)\\>")))
                            (font-lock-add-keywords  'emacs-lisp-mode
                                                     `((,keyword-regexp 1 ',face-name))))
                          (cl-mapc (lambda (x)
                                     (put (cdr x)
                                          'scheme-indent-function
                                          (car x)))
                                   keyword-rules)))

    (add-keywords
     'font-lock-builtin-face
     '((1 . vendle:initialize)
       (1 . vendle:turn-on-font-lock)
       (1 . vendle:register)
       (1 . vendle:register-local)
       (1 . vendle:register-theme)
       (1 . vendle:register-theme-local)))))

;;; provide
(provide 'vendle)
