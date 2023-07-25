# RS_Cloud_Resume_Challenge

## **Technologies Used :** AWS, Terraform, Python, HTML, CSS, JavaScript, GitHub Actions

## **AWS Services :** IAM, S3 Bucket, CloudFront, Route53, API Gateway, Lambda Function, DynamoDB, ACM

## **Infrastructure as Code :** Terraform 

## **CI/CD :** GitHub Actions

Frontend 
- Written My Portfolio using HTML, CSS, and JavaScript. This Static Site is hosted in the AWS CloudFront with Custom DNS using Route53
- The Connection to the Hosted Site is Secured with HTTPS Secure Connection with Proper TLS Viewer Certification Using ACM ( AWS Certificate Manager )
- The Site Files are uploaded to the AWS S3 Bucket, & From the S3 Bucket with Custom Policy from Origin Access Control - the files will be securely Accessed only by AWS CloudFront.
- Written Terraform to Automatically Upload the Files from a Specific Directory & perform all the aforementioned operations completely.

CI/CD
- Set up CI/CD Pipeline using GitHub Actions to Upload the Static files to the S3 Bucket whenever any new update is Pushed to the files. 

API  
- Configured & Deployed a REST API, That Processes the GET, and POST requests from the Endpoint and Invokes the Lambda Function.
- CORS has been Enabled in the API Gateway for the Allowed Methods & Origins


Backend 
- Configured Terraform File to Create a DynamoDB Table with Required Schema and Primary Keys.
- Developed a Lambda Function in Python, that process the incoming POST requests through API Gateway and manipulates the Data in the DyanmoDB table. 
- Configured Terraform File to Create a Lambda Function and Payload the Lambda Function Code Written in Python, Including Environmental Variables.

IAM 
- Provided IAM permissions to Lambda Function, API Gateway, S3 Buckets, and Cloudfront Distribution based on the Least Privilege Principle.