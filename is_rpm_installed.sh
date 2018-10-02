#!/usr/bin/env expect

# procedure to attempt connecting; result 0 if OK, 1 otherwise
proc connect {password} {
    expect {
        "Password:" {
            send -- "$password\r"
            expect {
                "myuser@*" {
                    return 0
                }
                # if at this point we get repeated password prompt - you entered invalid password for the user
                "Password:" {
                    return 2
                }
            }
        }
        "yes/no" {
            send -- "yes\r"
            exp_continue
        }
  }
  # timed out
  return 1
}

proc is_rpm_installed {} {
    # check if command returns anything
    send -- "rpm -q gcc\r"
    # traverse through output
    expect {
        "not installed" {
            return "Not installed"
        }
        -re "gcc-(.*)" {
            return "Installed : gcc-${expect_out(1,string)}"
        }
        # extremely useful to know that just no match occured
        timeout {
            return "No match found and timeout occured"
        }
    }
}

set type [lindex $argv 0]
set data [lindex $argv 1]
if { $type == "" || $data == "" } {
    puts "Usage: <hostname\/file> <hostname\/file with hosts>\n"
    exit 1
}
set password ""
# Request user password in a secure way and work around empty password pasted in
while {$password == ""} {
    stty -echo
    send_user -- "Enter Password: "
    expect_user -re "(.*)\n"
    send_user "\n"
    stty echo
    set password $expect_out(1,string)
}
set timeout 5
# Skip any stdout except explicitly specified
#exp_internal 1
# if type is file open it :-)
log_user 0
if { $type == "file" } {
    set f [open $data]
    set hosts [split [read $f] "\n"]
    close $f
} elseif { $type == "hostname" } {
    set hosts $data
} else {
    puts "Unknown type. Use file or hostname bareword."
}
puts "hostname,result"
foreach host $hosts {
    if {$host != ""} {
        spawn ssh $host
        set result [connect $password]
        if { $result == 0 } {
            set rpm_result [is_rpm_installed]
            puts "$host,$rpm_result"
            send -- "exit\r"
        } elseif { $result == 2 } {
            puts "$host,User password is wrong\n"
            # send control+c to stop login ettempt
            send -- \x03\r
        } else {
            puts "$host,Connection failed\n"
        }
    }
}
exit 0
