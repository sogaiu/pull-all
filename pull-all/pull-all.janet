(import sh)
(import path :as p)

(def ansi
  {:success "\e[32m"
   :error "\e[31m"
   :info "\e[33m"
   :reset "\e[39;49m"})

(defn success [msg]
  (string (ansi :success) msg (ansi :reset)))

(comment

  (success "yes!!!")
  # => "\e[32myes!!!\e[39;49m"

  )

(defn error [msg]
  (string (ansi :error) msg (ansi :reset)))

(comment

  (error "no!!!")
  # => "\e[31mno!!!\e[39;49m"

  )

(defn color-result [res msg]
  (if (= res :success)
    (success msg)
    (error msg)))

(comment

  (color-result :success "yeah!")
  # => "\e[32myeah!\e[39;49m"

  (color-result :not-success "nope!")
  # => "\e[31mnope!\e[39;49m"

  )

(defn indent
  [text level]
  (let [indentation (string/repeat " " level)
        lines (string/split "\n" text)
        indented-text (string/join lines (string "\n" indentation))]
    (string indentation indented-text)))

(comment

  (indent ```
This is a line of text.
This is another line of text.
Can you guess what this is a line of?
``` 2)
`
``  This is a line of text.
  This is another line of text.
  Can you guess what this is a line of?
``
`

  )

(defn info [msg]
  (string/join @[(ansi :info) msg (ansi :reset)]))

(comment

  (info "public service announcement")
  # => "\e[33mpublic service announcement\e[39;49m"

  )

(defn is-dir? [path]
  (= :directory
     (os/stat path :mode)))

(comment

  (is-dir? (os/getenv "HOME"))
  # => true

  )

# XXX: doesn't seem quite right
(defn dirs-old [path]
  (filter
   is-dir?
   (os/dir path)))

(comment

  (dirs-old "/usr")
  # => @[]

)

(defn dirs [path]
  (->> (filter
         (fn [subpath]
           (is-dir? (p/join path subpath)))
         (os/dir path))
    (map (fn [subpath]
           (p/join path subpath)))))

(comment

  (dirs "/usr")
  `@["/usr/lib64"
     "/usr/share"
     "/usr/include"
     "/usr/lib"
     "/usr/bin"
     "/usr/sbin"
     "/usr/local"
     "/usr/lib32"
     "/usr/src"]
  `

  )

(defn hidden? [path]
  (string/has-prefix?
   "."
   (p/basename path)))

(comment

  (hidden? (p/join (os/getenv "HOME") ".bashrc"))
  # => true

  )

(defn visible? [path]
  (not (hidden? path)))

(comment

  (visible? (p/join (os/getenv "HOME") "Desktop"))
  # => true

  )

(defn visible-dirs [path]
  (filter visible? (dirs path)))

(comment

  (visible-dirs "/usr")
  `@["/usr/lib64"
     "/usr/share"
     "/usr/include"
     "/usr/lib"
     "/usr/bin"
     "/usr/sbin"
     "/usr/local"
     "/usr/lib32"
     "/usr/src"]
  `

  )

(defn git-project? [path]
  (is-dir? (p/join path ".git")))

(comment

  (git-project? (os/getenv "HOME"))
  # => false

  (git-project? "..")
  # => true

  (git-project?
    (p/join (os/getenv "HOME") "src" "janet-repositories" "pull-all"))
  # => true

  )

# XXX: depth >= 2 doesn't work with old definition of dirs
(defn- search-directories* [path depth]
  (if (> depth 0)
    (array/push (mapcat |(search-directories* $0 (- depth 1))
                        (visible-dirs path))
                path)
    @[path]))

(comment

  (search-directories* "/usr" 1)
  `@["/usr/lib64"
     "/usr/share"
     "/usr/include"
     "/usr/lib"
     "/usr/bin"
     "/usr/sbin"
     "/usr/local"
     "/usr/lib32"
     "/usr/src"
     "/usr"]
  `

  (search-directories* "/usr/share/emacs" 2)
  `@["/usr/share/emacs/site-lisp"
     "/usr/share/emacs/26.3/site-lisp"
     "/usr/share/emacs/26.3/lisp"
     "/usr/share/emacs/26.3/etc"
     "/usr/share/emacs/26.3"
     "/usr/share/emacs"]
  `

  )

(defn search-directories [path depth]
  (search-directories* path depth))

(comment

  (search-directories "/usr" 1)
  `@["/usr/lib64"
     "/usr/share"
     "/usr/include"
     "/usr/lib"
     "/usr/bin"
     "/usr/sbin"
     "/usr/local"
     "/usr/lib32"
     "/usr/src"
     "/usr"]
  `

  )

(defn git-projects [path depth]
  (filter git-project? (search-directories path depth)))

(comment

  (comment

    (git-projects (p/join (os/getenv "HOME") "src" "janet-repositories") 1)

    )

  )

(defmacro repeat-map [n & body]
  ~(seq [_ :range [0 ,n]]
        (do ,;body)))

(defn pmap [f xs]
  (each el xs
    (thread/new
     |(:send $0 (f el))
     1
     :h))
  (repeat-map (length xs)
              (thread/receive 300)))

(defn run [& args]
  (let [buf @""
        status (first (sh/run* [;args :> buf :> [stderr stdout]]))]
    {:result (if (= 0 status) :success :error)
     :output (-> buf string/slice string/trimr)}))

(defn git-pull [dir]
  {:repo dir
   :pull (run "git" "-C" dir "pull")
   :branch (run "git" "-C" dir "rev-parse" "--abbrev-ref" "HEAD")})

(defn main [& args]
  (let [projects (git-projects "." 1)
        results (sort-by |($0 :repo) (pmap git-pull projects))]
    (each result results
      (let [{:repo repo
             :pull pull
             :branch branch} result]
        (print (color-result (pull :result) repo)
               (when (= :success (branch :result))
                 (string " (" (info (branch :output)) ")"))
               "\n"
               (indent (pull :output) 4)
               "\n")))))
