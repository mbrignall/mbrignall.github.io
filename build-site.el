;; Set the package installation directory so that packages aren't stored in the
;; ~/.emacs.d/elpa path.

(require 'package)
(setq package-user-dir (expand-file-name "./.packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(package-refresh-contents)

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; Install and load webfeeder
(use-package webfeeder)

;; Load publishing system
(require 'ox-publish)
(use-package htmlize)
(use-package ess)
(use-package ox-rss)
(use-package ob-nix)
(use-package esxml)

;;; Sitemap preprocessing
;;;; Get Preview

;; modify with an "if error skip" logic
;; still need conditional
(defun my/get-preview (file)
  "get preview text from a file

Uses the function here as a starting point:
https://ogbe.net/blog/blogging_with_org.html"
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (when (re-search-forward "^#\\+BEGIN_PREVIEW$" nil 1)
      (goto-char (point-min))
      (let ((beg (+ 1 (re-search-forward "^#\\+BEGIN_PREVIEW$" nil 1)))
            (end (progn (re-search-forward "^#\\+END_PREVIEW$" nil 1)
                        (match-beginning 0))))
        (buffer-substring beg end)))))

;;;; Format Sitemap
(defun my/org-publish-org-sitemap (title list)
  "Sitemap generation function."
  (concat "#+OPTIONS: toc:nil")
  (org-list-to-subtree list))

(defun my/org-publish-org-sitemap-format (entry style project)
  "Custom sitemap entry formatting: add date"
  (cond ((not (directory-name-p entry))
         (let ((preview (if (my/get-preview (concat "content/" entry))
                            (my/get-preview (concat "content/" entry))
                          "(No preview)")))
         (format "[[file:%s][(%s) %s]]\n%s"
                 entry
                 (format-time-string "%Y-%m-%d"
                                     (org-publish-find-date entry project))
                 (org-publish-find-title entry project)
                 preview)))
        ((eq style 'tree)
         ;; Return only last subdir.
         ;; ends up as a headline at higher level than the posts
         ;; it contains
         (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

(defun file-contents (file)
  "Return the contents of FILE as a string, or nil if the file does not exist."
  (if (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (buffer-string))
    (error "File not readable: %s" file)))

(setq org-html-postamble-format
      '(("en" "<div class=\"postamble\" style=\"text-align: center; margin-top: 20px; margin-bottom: 20px;\"> 
               <p> Created by %c %s </p>
               </div>")))

;; Define the publishing project
(setq org-publish-project-alist
      (list
       ;; Main content
       (list "org-site:main"
             :recursive t
             :base-directory "./content"
             :publishing-function 'org-html-publish-to-html
             :html-preamble (file-contents "assets/html_preamble.html")
             :html-postamble t
             :publishing-directory "./public"
	     :headline-levels 4
             :with-author nil
             :with-creator nil
	     :with-tags t
             :with-toc nil
             :section-numbers nil
             :auto-sitemap t
             :sitemap-title "mblognl"
             :sitemap-format-entry 'my/org-publish-org-sitemap-format
             :sitemap-function 'my/org-publish-org-sitemap
             :sitemap-sort-files 'anti-chronologically
             :sitemap-filename "sitemap.org"
             :sitemap-style 'tree
             :time-stamp-file nil
             :html-doctype "html5"
             :html-html5-fancy t
             :htmlized-source t
             :with-todo-keywords t
             :exclude "^posts/drafts/.*")  ;; Corrected exclude pattern

       ;; Static assets
       (list "org-site:static"
             :base-directory "./static/"
             :base-extension "css\\|js\\|png\\|jpg\\|jpeg\\|gif\\|pdf\\|mp3\\|ogg\\|swf\\|svg"
             :publishing-directory "./public/img"
             :recursive t
             :publishing-function 'org-publish-attachment
             :exclude "^posts/drafts/.*")  ;; Corrected exclude pattern

       ;; Other assets (CSS, images, etc.)
       (list "org-site:assets"
             :base-directory "./assets/"
             :base-extension "css\\|ico\\|js\\|png\\|jpg\\|jpeg\\|gif\\|pdf\\|mp3\\|ogg\\|swf\\|ico"
             :publishing-directory "./public"
             :recursive t
             :publishing-function 'org-publish-attachment)))

;;; additional settings
(setq org-html-validation-link nil
      org-html-htmlize-output-type 'css
      org-html-style-default (file-contents "assets/head.html")
      org-export-use-babel t)

(org-babel-do-load-languages
 'org-babel-load-languages
 '((nix . t)))

;; Customize export for Nix code blocks
(setq org-src-lang-modes
      (append '(("nix" . nix)) org-src-lang-modes))  ;; Ensure Nix gets mapped correctly

;; Generate the site output
(org-publish-all t)

;;; build RSS feed

;;;; https://codeberg.org/SystemCrafters/systemcrafters-site/src/commit/ce3717201ab727f709f9e739842b209d10c8c51a/publish.el#L411
;;;; https://codeberg.org/SystemCrafters/systemcrafters-site/src/commit/ce3717201ab727f709f9e739842b209d10c8c51a/publish.el#L418
(defun dw/rss-extract-date (html-file)
  "Extract the post date from an HTML file."
  (with-temp-buffer
    (insert-file-contents html-file)
    (let* ((dom (libxml-parse-html-region (point-min) (point-max)))
           (date-node (car (dom-by-class dom "date")))
           (date-string (when date-node (dom-text date-node))))
      (if date-string
          (let* ((parsed-date (parse-time-string date-string))
                 (day (nth 3 parsed-date))
                 (month (nth 4 parsed-date))
                 (year (nth 5 parsed-date)))
            ;; Check if the parsed date is valid, otherwise fallback to current date
            (if (and day month year)
                (encode-time 0 0 8 day month year)
              (current-time))) ;; Fallback to current time if date is invalid
        (current-time))))) ;; Fallback to current time if no date is found

;(defun dw/rss-extract-summary (html-file)
;  )

(setq webfeeder-date-function #'dw/rss-extract-date)

;;;; https://gitlab.com/ambrevar/emacs-webfeeder/-/blob/master/webfeeder.el
(webfeeder-build "rss.xml"
                 "./public"
                 "https://blog.mbrig.nl"
                 (mapcar (lambda (file) (concat "posts/" file))
                         (let ((default-directory (expand-file-name "./public/posts/")))
                           (directory-files-recursively "./" ".*\\.html$")))
                 :builder 'webfeeder-make-rss
                 :title "mblognl"
                 :description "moments of clarity, shared."
                 :author "mbrignall")


(message "Build Complete!")

