# SLURM job watchdog

Programs like R have [known misbehavior](https://stackoverflow.com/a/17976175)
of hanging when initially creating a cluster.

To workaround such intermittent failures to launch correctly on an HPC cluster,
one can run a timer in the SLURM shell script to kill and restart the program
if it does not generate the expected output or it it generates an error message.

Such an example is illustrated in `watchdog.slurm`.

# Usage

You can run test the program as is either inside or outside of a SLURM job:

``` bash
# Inside SLURM
touch out.slurm &&
	sbatch watchdog.slurm &&
	tail -f out.slurm  # Ctrl+C to exit.

# Outside SLURM
bash watchdog.slurm
```

Example output from is below.
The program writes informational messages to stderr
in the line format "Seconds elapsed [Function] Informational message"

```
0 [Main] Begin: Script PID 44542
1 [Check] Missing program expected output.
1 [Rerun] Setting timer to 5 seconds.
1 [Rerun] Launching program.
1 [Program] Iteration 1: output hung.
6 [Timer] Sending alarm to PID 44542.
6 [Handler] Entered timeout handler.
6 [Check] Missing program expected output.
6 [Handler] Listing running programs:
[2]+ 44564 Running                 my_program &
6 [Handler] Killing most recently backgrounded program PID 44564.
6 [Handler] Waiting for program to terminate before re-running.
watchdog.slurm: line 61: 44564 Terminated              my_program
6 [Check] Missing program expected output.
6 [Rerun] Setting timer to 5 seconds.
6 [Rerun] Launching program.
6 [Program] Iteration 2: output hung.
11 [Timer] Sending alarm to PID 44542.
11 [Handler] Entered timeout handler.
11 [Check] Missing program expected output.
11 [Handler] Listing running programs:
[3]+ 44604 Running                 my_program &
11 [Handler] Killing most recently backgrounded program PID 44604.
11 [Handler] Waiting for program to terminate before re-running.
watchdog.slurm: line 61: 44604 Terminated              my_program
11 [Check] Missing program expected output.
11 [Rerun] Setting timer to 5 seconds.
11 [Rerun] Launching program.
11 [Program] Iteration 3: output hung.
16 [Timer] Sending alarm to PID 44542.
16 [Handler] Entered timeout handler.
16 [Check] Missing program expected output.
16 [Handler] Listing running programs:
[4]+ 44646 Running                 my_program &
16 [Handler] Killing most recently backgrounded program PID 44646.
16 [Handler] Waiting for program to terminate before re-running.
watchdog.slurm: line 61: 44646 Terminated              my_program
16 [Check] Missing program expected output.
16 [Rerun] Setting timer to 5 seconds.
16 [Rerun] Launching program.
16 [Program] Iteration 4: success!
21 [Timer] Sending alarm to PID 44542.
21 [Handler] Entered timeout handler.
21 [Check] Program expected output found!
21 [Check] Program expected output found!
21 [Main] End
```

To modify the job script for your program,
you probably want to:

1. Replace the toy Python program in the `my_program()` function with your
   command line(s), and replace all the `module load ...` packages in `main()`
   to setup your software environment.
2. Replace all instances of `prog.out` to the output file that will be generated
   by your program.
3. Set the `timeout=5` argument in `rerun_program()` to a value more appropriate
   for your program.  Because the value is directly used by `sleep`, you can add
   time units.  For example you can set `timeout=10m` to schedule a check at 10
   minutes.  See `man sleep`.
4. Change the various `#SLURM` header directives as needed.
