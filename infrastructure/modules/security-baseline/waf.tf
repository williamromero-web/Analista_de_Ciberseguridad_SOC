resource "aws_wafv2_web_acl" "main" {
  #checkov:skip=CKV_AWS_192: "Reglas contra Log4j2 omitidas para mantener simplicidad en IaC"
  #checkov:skip=CKV2_AWS_31: "WAF Logging configuration (Kinesis) omitido por alcance"
  
  name        = "${var.company_name}-web-acl"
  description = "WAF restrictivo para la aplicacion"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-main"
    sampled_requests_enabled   = true
  }

  # 1. Reglas Administradas por AWS
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # 2. Rate Limiting (1000 req / 5 min)
  rule {
    name     = "RateLimit1000"
    priority = 2
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # 3. Geo Restriccion (CO, PE, US) - Bloquea si NO es de esos paises
  rule {
    name     = "GeoRestriction"
    priority = 3
    action {
      block {}
    }
    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["CO", "PE", "US"]
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "geo-restriction"
      sampled_requests_enabled   = true
    }
  }
}