
**The Beauty of CloudInit**

Over the past few weeks, for work and for side-projects added up a learning curve to cloud-init, I have moved to deploying my web applications into the cloud. 

So I set out to use various built-in utilities and hooks to implement something similar that satisfied my needs. I looked a bunch of tools from Chef/Knife to Puppet.But again, the examples there showed me some of the ways that I should be thinking about what I wanted to do. Ultimately, here is what I came up with:

+ I want to be able to go from nothing to a server running my application in two minutes

+ I want to be able to repeat this process over and over with no intervention

+ I want to be able to apply the process to any Amazon Machine Image (AMI) of choice for upgrades/shifts; so I don’t want to bundle assets into a custom AMI

+ I want to be able to securely and reliably host/store my application’s assets

+ I may want to be able to parameterize parts of the setup so I can have different server roles, or deployment configurations

+ I want the whole process to be secure

Ultimately, this lead me to the “User Data” box that appears when you launch an EC2 instance. There is also a command line flag to pass in this data in the EC2 command line tools.

What goes in that box? Well, its processed by a module called CloudInit. At least if you are using a Ubuntu AMI or an Amazon AMI (which I am). There isn’t much documentation on the format though. That link earlier is really all I found. So I decided to start with that and see what I could come up with.

So basically CloudInit can process a shell script or other types of data and run it. Cool. But I don’t want to paste a bunch of shell script code in that box on the EC2 launch page. Hmmm. Turns out you can give that page a syntax like:

#include

http://hostname/script1

http://hostname/scrpt2

It will download those 2 files from their URLs and execute them in order. Execution goes back to the various CloudInit formats so it can be a shell script itself or another one of the formats. So I could put a series of scripts on another “host” server and pull them down and it would run them. I am starting to like the sound of this.

The next catch was that I wanted these scripts and other assets (the application server, my code, etc.) to be secured. The scripts might need to have some security token stuff in them too. So serving them from some random web server isn’t going to work. I looked back at AWS and saw a solution using S3. S3 is the “super data storage” feature of the cloud. You can put files up there and they are virtually indestructible. Great place to keep stuff safe. Plus, you don’t have to pay bandwidth charges between an EC2 instance and an S3 bucket. That should help a bit. So what I will do is put all my assets up in an S3 bucket and build URLs to fetch all of it via CloudInit. Sweet.

The next catch was that I didn’t want these files on S3 to be public but I needed some way of getting my EC2 server to actually download them. To do that, the EC2 server would need my AWS credentials and that is a bit of a no-no. Plus, there was this chicken-egg problem. If I put the credentials in a file on S3 to download, I would need credentials to download them. I don’t want to put the credentials into the User Data because that is stored in text in various parts of EC2. Thought I was at a dead end. Until I learned about “expiring signed S3 URLs”. These are URLs that you can generate for your assets that include your AWS ID, a signature, and an expires timeout. You can generate them for however long you want. Anyone with the URL can get the file. So what I can do is generate these URLs for every asset I want and give them say a 5 minute window. My boot only is going to take 2 minutes so that should be long enough. More on the URLs in a minute.

To generate the URLs, you might want a helper library. I used this Python one. It had some sample code in it that got me thinking further. It had the ability to add stuff to an S3 bucket, iterate the bucket, generate signed URLs, and more. So what if I adapt that to look into some specific bucket and iterate over everything in there in sorted order. Then build signed URLs for everything it finds. The result was something like this:

#include

https://localcounsel-cloudinit.s3.amazonaws.com:443/1-install-httpd?AWSAccessKeyId=MYKEY&Signature=vSzCjZsf4JJn0wtOcCFeTJCgYLU%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/2-fetch-jboss-auto?AWSAccessKeyId=MYKEY&Signature=DpR%2BKo5r7%2Bl9cGv9g%2B1%2BqQxyrt4%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/2-fetch-jboss-initd-auto?AWSAccessKeyId=MYKEY&Signature=60ibmrXWceUEeGedLCj2v9CVpl0%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/2-fetch-localcounselconf-auto?AWSAccessKeyId=MYKEY&Signature=vsotf7gQSMwzNBan83zx3E%2FJTNA%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/2-fetch-mailxml-auto?AWSAccessKeyId=MYKEY&Signature=liuX%2BLOyWCmDbsowB%2B2yw4I51Tw%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/2-fetch-mysqldsxml-auto?AWSAccessKeyId=MYKEY&Signature=y2mdVFOsBX4xT6hYX1S1kPQZ1n8%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/2-fetch-properties-auto?AWSAccessKeyId=MYKEY&Signature=Imz1TjFlJQ0C7nwKaDmRnjAzGIE%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/2-fetch-software-auto?AWSAccessKeyId=MYKEY&Signature=XGvKHmgsu0q6sV7vTcMHMLS3NKQ%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/3-install-jboss?AWSAccessKeyId=MYKEY&Signature=jBKwAGkx5Hq0dQCcrRshDlWitTk%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/4-config-httpd?AWSAccessKeyId=MYKEY&Signature=CgOwAMDEpphyG6EEu0dy7ReSxfE%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/6-install-jboss-initd?AWSAccessKeyId=MYKEY&Signature=om7ESk8cdszGCLIJ0X2Ct4BqZ%2BI%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/8-create-indexes?AWSAccessKeyId=MYKEY&Signature=phhwYOYy3wtj9g9AXKMs%2BeNO5y4%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/8-deploy-jboss?AWSAccessKeyId=MYKEY&Signature=u%2Fcg1G3ljVKGzaZfQzx1%2Bu9aoRQ%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/9-start-httpd?AWSAccessKeyId=MYKEY&Signature=sXRq80jcdqMyEBAZBdmJDh0n7xw%3D&Expires=1304219569

https://localcounsel-cloudinit.s3.amazonaws.com:443/9-start-jboss?AWSAccessKeyId=MYKEY&Signature=z6CXtS1D0Y6ShWFaBKITCcPig4c%3D&Expires=1304219569

So I run my new script and it generates this output which is in CloudInit “User Data” format for EC2 launches. Notice the signed URLs. Click them if you like. They are all expired by now. I added all these scripts to my bucket and ordered them by number so I could perform this server start-up in a stepwise manner. So it first installs the web server, then the application server, then configures everything, then starts it up. Sure there is a bunch more to the scripts but they are all mostly just common UNIX shell scripts that do what I need done.

A few things I ran into:

+ To debug, I looked into the cloud log at /var/log

+ I was trying to use the #cloud-config file in multiple files but it wasn’t working well. It seemed like the last #cloud-config ended up being the only one executed. So I ended up using only 1 #cloud-config to install packages and left everything else up to regular old shell scripts that I know how to write and debug. Plus, you can just test them by hand.

+ The process runs as root so you don’t need to mess with “su” or “sudo”

+ I had to remember to keep specifying full paths like a good scripter

I later moved all my assets that I wanted to install into a different S3 bucket and wrote a little section in that Python script that created little fetch scripts using WGET to pull down the assets.

Took me a few tries but now I can run my script, get the output, launch an instance with it, and be up and running with a fully available server in minutes. You could imagine taking this a step further and tying that logic into scripts that detect the health or load of a machine as well. Will worry about that some day in the future.

The real key lessons here are:

+ Using S3 for asset storage

+ Using S3 for a script repository

+ Accessing S3 via signed timed URLs

+ Using CloudInit to setup your server in minutes

Hope that helps you in your cloud efforts.

