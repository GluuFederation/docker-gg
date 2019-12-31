# docker-gg
Docker container repo for Gluu Gateway (GG)

We have used the tool `ONVAULT` can be found here [ONVAULT](https://github.com/dockito/vault) to make use of ssh keys while building the image. ONVAULT makes sure your keys are deleted immediately after use in the build process.

Make sure to add your public key to Github. See instructions [here](https://help.github.com/en/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account) 

### Instructions

Before running `make` command, start dockito server by running 
`docker run -p `ifconfig docker0 | grep 'inet ' | cut -d: -f2 | awk '{ print $2}'`:14242:3000 -v ~/.ssh:/vault/.ssh dockito/vault` then run make command.
