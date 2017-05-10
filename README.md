# overview_widget.sh

![Image of overview_widget](https://github.com/developerhdf/overview_widget/blob/master/i3status_widget.png)

A simple system monitor type widget for i3 + i3bar + i3status.

To see a more detailed demonstration of the widget, please look [here](https://github.com/developerhdf/overview_widget/blob/master/demonstration.png).

## Getting it to run:

Make sure you have timew, i3 and i3status installed on your machine. Also, 
this script reports on battery status as I am using a laptop at present. If 
neither the timew nor battery monitoring is required, comment out the relevant
sections. In your i3 config, comment out the line 
'status_command i3status'
and replace it with:
'status_command exec ~/path_to_script/script_name.sh'


## Please note:

I am aware there must be better ways to do much of what this script does. That
is why I released it as open source software - anyone can hack at it and I 
hope some of those that do will share their improvements with me, even though 
the license does not require it. I had an idea for the kind of widget I wanted 
to run next to the clock in i3bar and then used Google to implement it. 

What follows, therefore, is not remotely close to professional bash scripting 
or even good programming practice. Consider this alpha software that does what
the author intended it to do, without any considerations for security,
performance or good programming practice.

This script relies on timew being installed on the computer it is run on.
Also, I am using a laptop so it monitors my battery level which might produce 
errors on computers without batteries. If time/task and battery monitoring is
not required, please comment out the relevant code. I wrote the script on Arch 
Linux and am not aware of any other "dependencies", but should any be 
discovered I will greatly appreciate being notified of the fact.
