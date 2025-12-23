plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = false
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}
