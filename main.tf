provider "aws" {

  region                   = "us-east-1"
  shared_credentials_files = ["$HOME/.aws/credentials"]
  shared_config_files      = ["$HOME/.aws/config"]

}

resource "aws_s3_bucket" "mybucks" {
    bucket = "ramshiv-buks-wicket-out"

}

resource "aws_s3_bucket_policy" "cf_s3_acess" {
  depends_on = [ aws_cloudfront_distribution.s3_distribution ]
  
  bucket = aws_s3_bucket.mybucks.id
  policy = data.aws_iam_policy_document.s3_cf_access_policy.json
}

data "aws_iam_policy_document" "s3_cf_access_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [

      aws_s3_bucket.mybucks.arn,
      "${aws_s3_bucket.mybucks.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    } 
  }
}

output "policy_out" {

    value = aws_s3_bucket_policy.cf_s3_acess.policy
}

# Upload files to S3 Bucket 

resource "aws_s3_object" "provision_source_files" {
    bucket  = aws_s3_bucket.mybucks.id
    for_each = fileset("myapp/", "**/*.*")
    


    key    = each.value
    source = "myapp/${each.value}"
    content_type = each.value
    #content = each.value.content
    
    
}


locals {
    s3_origin_id = "myS3Origin"
}

output "originidval" {
    value = aws_s3_bucket.mybucks.bucket_domain_name
    

}

output "regional" {
    
    value = aws_s3_bucket.mybucks.bucket_regional_domain_name

}

resource "aws_cloudfront_origin_access_control" "mycfoac" {
    name                              = "CRCresumepolicy"
    description                       = "cloud resume Policy"
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {

    origin {
        domain_name              = aws_s3_bucket.mybucks.bucket_regional_domain_name
        origin_access_control_id = aws_cloudfront_origin_access_control.mycfoac.id
        origin_id                = local.s3_origin_id
    }

    enabled = true

    default_root_object = "index.html"

    default_cache_behavior { 
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id

        min_ttl                = 0
        default_ttl            = 0
        max_ttl                = 0
        viewer_protocol_policy = "redirect-to-https"

        forwarded_values {
            query_string = false

        cookies {
            forward = "none"
        }
        }

    }

    
    restrictions {
        geo_restriction {
            restriction_type = "none"
            locations        = []
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}



output "cfdata" {
    value = local.s3_origin_id
}

output "domainname" {
    value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "arncf" {
    value = aws_cloudfront_distribution.s3_distribution.arn
}


# Create A DynamoDB Table 

resource "aws_dynamodb_table" "resume_db_data" {
  name           = "crc_test"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user"

  attribute {
    name = "user"
    type = "S"
  }

}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.py"
  output_path = "lambda_function_payload.zip"
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = "cloud-resume-challenge"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.lambda_handler"


  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.10"

  environment {
    variables = {
      TableName = "crc_test" #TODO: Dynamic Dynamodb Table Name
    }
  }
}

resource "aws_api_gateway_rest_api" "MyResAPI" {
  name        = "CRCresumeAPI"
  description = "AWS Cloud Resume Challenge"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "MyApiResource" {
  rest_api_id = aws_api_gateway_rest_api.MyResAPI.id
  parent_id   = aws_api_gateway_rest_api.MyResAPI.root_resource_id
  path_part   = "counter"
}

resource "aws_api_gateway_method" "MyApiMethod" {
  rest_api_id   = aws_api_gateway_rest_api.MyResAPI.id
  resource_id   = aws_api_gateway_resource.MyApiResource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "api_integration" {
  rest_api_id             = aws_api_gateway_rest_api.MyResAPI.id
  resource_id             = aws_api_gateway_resource.MyApiResource.id
  http_method             = aws_api_gateway_method.MyApiMethod.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.test_lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.MyResAPI.id
  resource_id = aws_api_gateway_resource.MyApiResource.id
  http_method = aws_api_gateway_method.MyApiMethod.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "api_integration_response" {

  depends_on = [ aws_api_gateway_integration.api_integration ]
  rest_api_id = aws_api_gateway_rest_api.MyResAPI.id
  resource_id = aws_api_gateway_resource.MyApiResource.id
  http_method = aws_api_gateway_method.MyApiMethod.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_deployment" "api_deploy" {
  rest_api_id = aws_api_gateway_rest_api.MyResAPI.id

   triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.MyApiResource.id,
      aws_api_gateway_method.MyApiMethod.id,
      aws_api_gateway_integration.api_integration.id,
    ]))
  }
 lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.api_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.MyResAPI.id
  stage_name    = "myStage"
}

resource "aws_apigatewayv2_api" "lambda_api" {
  name          = aws_api_gateway_rest_api.MyResAPI.id
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["*"]
    max_age = 300
  }
}


# Provide permission to API Gateway for Invoke Lambda
resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowMyResAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The /* part allows invocation from any stage, method and resource path
  # within API Gateway.
  source_arn = "${aws_api_gateway_rest_api.MyResAPI.execution_arn}/*"
}


output "api_url" {
  value = aws_api_gateway_stage.example.invoke_url
}