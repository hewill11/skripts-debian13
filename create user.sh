 #!/bin/bash
useradd -m -s /bin/bash user1
echo "user1:Password1" | chpasswd

useradd -m -s /bin/bash user2
echo "user2:Password2" | chpasswd

usermod -aG sudo user2

su - user1
#лол