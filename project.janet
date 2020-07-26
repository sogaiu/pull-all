(import ./vendor/path)

(declare-project
 :name "pull-all"
 :description "Pulls all the immediately nested git repositories and the current directory."
 :dependencies ["https://github.com/andrewchambers/janet-sh.git"
                "https://github.com/janet-lang/path.git"])

(def proj-root
  (os/cwd))

(def proj-dir-name
  "pull-all")

(def src-root
  (path/join proj-root proj-dir-name))

(declare-executable
 :name "pull-all"
 :entry (path/join src-root "pull-all.janet"))

(phony "netrepl" []
       (os/execute
        ["janet" "-e" (string "(os/cd \"" src-root "\")"
                              "(import spork/netrepl)"
                              "(netrepl/server)")] :p))

(phony "judge" ["build"]
       (os/execute ["jg-verdict"
                    "-p" proj-root
                    "-s" src-root] :p))
