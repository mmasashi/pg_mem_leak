This script is for reproducing a memory leak issue

How to use:
  - Edit config.rb and set your PostgreSQL db config
  - Run "bundle install"
  - Run "bundle exec ruby setup" to create a table on your PostgreSQL server
  - Run "bundle exec ruby mem_leak.rb <pattern-no(1-12) (required)> <num_exec(default: 10) (optional)>"

This scirpt loops the following steps every 5 seconds
- Run a select query (Only first num_exec(default: 10) iterations)
- Call GC.start
- Sleep 5 seconds

After the number of query counts reach the num_exec(default: 10), running a query will be skipped.
Instead, it will call only GC.start with sleep to check if the memory usage is going down.

See run_once method about the patterns.

Examples:

(1) Leak pattern - Memory does not go down
```
$ bundle exec ruby mem_leak.rb 2 3
mem: 0.1%
---- pattern:2 cnt:1/3 running query and start GC
mem: 0.9%
mem: 0.9%
---- pattern:2 cnt:2/3 running query and start GC
mem: 1.2%
mem: 1.2%
---- pattern:2 cnt:3/3 running query and start GC
mem: 1.5%
mem: 1.5%
---- cnt:4/3 starts only GC
mem: 1.5%
mem: 1.5%
---- cnt:5/3 starts only GC
mem: 1.5%
mem: 1.5%
---- cnt:6/3 starts only GC
mem: 1.5%
mem: 1.5%
```

(2) No leak pattern - Memory goes down
```
$ ruby mem_leak.rb 3 3
mem: 0.1%
---- pattern:3 cnt:1/3 running query and start GC
mem: 0.8%
mem: 0.8%
---- pattern:3 cnt:2/3 running query and start GC
mem: 1.0%
mem: 1.0%
---- pattern:3 cnt:3/3 running query and start GC
mem: 1.1%
mem: 1.1%
---- cnt:4/3 starts only GC
mem: 1.0%
mem: 1.0%
---- cnt:5/3 starts only GC
mem: 1.0%
mem: 1.0%
---- cnt:6/3 starts only GC
mem: 0.9%
mem: 0.9%
```
