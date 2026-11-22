# Single table design. Access pattern: "deployments for an environment since time T".
#   pk = ENV#<environment>
#   sk = <finished_at ISO 8601>#<id>
resource "aws_dynamodb_table" "this" {
  name                        = var.name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  range_key                   = "sk"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}
