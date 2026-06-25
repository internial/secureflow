## Github action security ![][image1]check:

Ci.yml all security check success.

Infra.yml AWS infra running successfully.  
![][image2]

## Grafana load tested results/metrics:

![][image3]

   
 

K8

![][image4]

* ALB DNS: k8s-securefl-securefl-79ebebac3c-1146011751.us-east-1.elb.amazonaws.com  
* ECR repo: 054041090724.dkr.ecr.us-east-1.amazonaws.com/secureflow

## Grafana, Simulation crash: 1 pod gets deleted, then auto heals back to normal(2 pods).

![][image5]

# AWS console:

CFN stack  
![][image6]

K8 cluster  
![][image7]

RDS  
![][image8]

Application Load balancer  
![][image9]

## Some users in database:

![][image10]

The k6 test created and deleted \~7,434 users, each iteration did POST (create) then DELETE (clean up).  


[image1]: images/production run pics_image1_973720769.png

[image2]: images/production run pics_image2_2149941432.png

[image3]: images/production run pics_image3_2720016540.png

[image4]: images/production run pics_image4_922359570.png

[image5]: images/production run pics_image5_1800433388.png

[image6]: images/production run pics_image6_3696428070.png

[image7]: images/production run pics_image7_3682575457.png

[image8]: images/production run pics_image8_1964217719.png

[image9]: images/production run pics_image9_916056477.png

[image10]: images/production run pics_image10_94168800.png