#!/bin/bash
#SBATCH --job-name watchdog-demo
#SBATCH --partition debug
#SBATCH --time 1:00
#SBATCH --output out.slurm

if [[ -n $SLURM_JOB_ID ]]; then
    # Clear previous SLURM job output.
    echo > out.slurm
    # Helpful SLURM debug information if we are in a SLURM job.
    scontrol show job $SLURM_JOB_ID
fi

# Example program for which we want to check the output.  If the
# program is "successful", it writes to prog.out, otherwise prog.out
# is empty.
my_program() {
    python <<EOF
import sys
import time

# Check how many times the program has been run.
with open("prog.counter") as handle:
    counter = int(handle.read())

message = f"$SECONDS [Program] Iteration {counter + 1}: "

# Increment counter.
with open("prog.counter", "w") as handle:
    handle.write(str(counter + 1))

# Fail the first 3 times.
if counter < 3:
    print(message + "output hung.", file=sys.stderr)
    # Wait indefinitely.
    while True:
        time.sleep(1000)

# Succeed after 3 times.
with open("prog.out", "w") as handle:
    handle.write("The message you were waiting for.")
print(message + "success!", file=sys.stderr)
EOF
}

timeout_handler() {
    # An unusual thing about handler functions is that they seem to
    # have no association with the calling function.  The handler
    # function must therefore call another function to continue the
    # script, otherwise the script will exit.
    echo >&2 "$SECONDS [Handler] Entered timeout handler."

    check_output && return

    echo >&2 "$SECONDS [Handler] Listing running programs:"
    jobs -rl
    pid=$!
    echo >&2 "$SECONDS [Handler] Killing most recently backgrounded program PID $pid."
    kill %%
    echo >&2 "$SECONDS [Handler] Waiting for program to terminate before re-running."
    wait $pid
}

# How long before checking on the program output file.
allow_time() {
    # Run timer process in subshell.
    (
	sleep $1
	# Send SIGALRM to parent process.
	echo >&2 "$SECONDS [Timer] Sending alarm to PID $$."
	kill -ALRM $$
    ) &
}

# Search for specific text in our program output file to consider it
# successful.
check_output() {
    local magic_string
    magic_string="message you were waiting for"

    if grep -q "$magic_string" prog.out; then
	echo >&2 "$SECONDS [Check] Program expected output found!"
	return 0
    fi
    echo >&2 "$SECONDS [Check] Missing program expected output."
    return 1
}

# Set timer and run program.
rerun_program() {
    timeout=5
    echo >&2 "$SECONDS [Rerun] Setting timer to $timeout seconds."
    allow_time $timeout    
    echo >&2 "$SECONDS [Rerun] Launching program."
    my_program &
}

main() {
    echo >&2 "$SECONDS [Main] Begin: Script PID $$"
    module purge
    module load tcl/8.6.6.8606 sqlite/3.18.0 python/3.6.1
    
    # my_program() will hang a few times.  The prog.counter file
    # tracks how many times my_program() was run.  The prog.out is a
    # file written by my_program() that we want to inspect for output.
    echo 0 > prog.counter
    echo > prog.out
    trap timeout_handler ALRM
    while ! $(check_output); do
	rerun_program
	# Wait for all backgrounded Bash jobs.
	wait
    done
    echo >&2 "$SECONDS [Main] End"
}

main
