
resource "helm_release" "system_rules_ingestor" {
  name             = var.system_rules_ingestor_release_name
  chart            = "${path.module}/${var.system-rules-ingestor_chart_path}"
  namespace        = var.system_rules_ingestor_namespace
  create_namespace = var.system_rules_ingestor_create_namespace
  depends_on       = [var.system_rules_ingestor_depends_on]
  timeout          = var.system_rules_ingestor_install_timeout
  force_update     = true
  cleanup_on_fail  = true
  atomic           = true

  values = [
    templatefile("${path.module}/${var.system_rules_ingestor_custom_values_yaml}", {
      env                                         = var.env
      building_block                               = var.building_block
      system_rules_ingestor_container_registry     = var.system_rules_ingestor_container_registry
      system_rules_ingestor_image_name             = var.system_rules_ingestor_image_name
      system_rules_ingestor_image_tag              = var.system_rules_ingestor_image_tag
      namespace                                    = var.system_rules_ingestor_namespace
    })
  ]
}