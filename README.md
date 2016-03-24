# Developer Machine Setup Scripts
I've built this script to help setting up development machines, easier. I use it whenever I setup a new machine, even if it's not for development purposes (but mostly it is). Currently I only have a Windows-version of it, but I am considering a Linux-one as well.

The script is mainly using Chocolatey as a package manager for Windows out of a PowerShell script. It automates the setup process as far as possible, but not entirely. The reason for that is that some installations modify environment variables or even require a re-start. That means the script needs to be started in several phases.

[Click here to get to the full documentation on my blog!](http://blog.mszcool.com/index.php/2016/02/my-developer-machine-setup-automation-script-chocolatey-powershell-published/)

First I do install some pre-requisites, typically the following Windows Components: 
* .NET Framework 3.5 
* Hyper-V for virtualization and e.g. phone emulators

After that, I typically perform the following actions on a blank Windows machine:

    # Enable Chocolatey and my script execution without being blocked
    Set-ExecutionPolicy Unrestricted
    
    # 1st Script Execution - Installing Chocolatey 
    .\Install-WindowsMachine.ps1 -installChoco 
    
    # 2nd Script Execution - development environments
    # Visual Studio I often install manually as mostly I need the Enterprise Edition
    .\Install-WindowsMachine.ps1 -installVs -vsVersion 2015 -installOtherIDE
    
    # 3rd Script Execution - remaining tools I typically use
    .\Install-WindowsMachine.ps1 -tools -ittools -dev -data
    
    # 4th Script Execution - Needs opening up a NEW PowerShell Window
    #                        Installs Visual Studio Extensions, SDKs etc. that
    #                        depend on the previous things being in the path.
    #                        Also clonse github-repository I typically use.
    .\Install-WindowsMachine.ps1 -dev2 -vsext -vsVersion 2015 -cloneRepos
    
    # 5th Script Execution - Install Database servers (I don't do that on most machines)
    .\Install-WindowsMachine.ps1 -dataSrv
    
There are many thoughts for improving the script. E.g. one I have is putting this all into a PowerShell workflow that can be restarted even after machine reboots from where it stopped before. But that will need some time - and since this is a spare-time project, I don't know when I'll get to it.

Finally - I am accepting pull requests for this, as well. So if you have an idea to improve the overall flow of the script, feel free to get into a pull request.

Happy Installing!!!
    

