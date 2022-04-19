locals {
  name          = "ibmcloud-operator"
  config_name   = "ibmcloud-operator-config"
  bin_dir       = module.setup_clis.bin_dir
  operator_yaml_dir = "${path.cwd}/.tmp/${local.name}/chart/${local.name}"
  config_yaml_dir = "${path.cwd}/.tmp/${local.name}/chart/ibmcloud-operator-config"
  secret_dir = "${path.cwd}/.tmp/${local.name}/secrets"
  values_content = {
    global = {
      clusterType = "ocp4"
    }
    ibmcloud-operator = {
      configNamespace = var.namespace
    }
  }
  application_branch = "main"
}

module setup_clis {
  source = "cloud-native-toolkit/clis/util"
  version = "1.9.3"

  clis = ["igc", "jq", "kubectl"]
}

resource null_resource create_operator_yaml {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-yaml.sh '${local.name}' '${local.operator_yaml_dir}'"

    environment = {
      VALUES_CONTENT = yamlencode(local.values_content)
    }
  }
}


resource null_resource setup_operator_gitops {
  depends_on = [null_resource.create_operator_yaml]

  triggers = {
    name = local.name
    namespace = "openshift-operators"
    yaml_dir = local.operator_yaml_dir
    server_name = var.server_name
    layer = "infrastructure"
    type = "operators"
    git_credentials = yamlencode(var.git_credentials)
    gitops_config   = yamlencode(var.gitops_config)
    bin_dir = local.bin_dir
  }

  provisioner "local-exec" {
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --delete --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }
}

resource null_resource create_secrets {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-secret.sh '${var.namespace}' '${var.region}' '${local.secret_dir}'"

    environment = {
      IBMCLOUD_API_KEY = nonsensitive(var.ibmcloud_api_key)
      BIN_DIR = module.setup_clis.bin_dir
    }
  }
}

module seal_secrets {
  depends_on = [null_resource.create_secrets]

  source = "github.com/cloud-native-toolkit/terraform-util-seal-secrets.git?ref=v1.0.2"

  source_dir    = local.secret_dir
  dest_dir      = local.config_yaml_dir
  kubeseal_cert = var.kubeseal_cert
  label         = "ibmcloud-operator-config"
}

resource null_resource setup_operator_config {
  depends_on = [null_resource.setup_operator_gitops, module.seal_secrets]

  triggers = {
    name = local.config_name
    namespace = var.namespace
    yaml_dir = local.config_yaml_dir
    server_name = var.server_name
    layer = "infrastructure"
    type = "base"
    git_credentials = yamlencode(var.git_credentials)
    gitops_config   = yamlencode(var.gitops_config)
    bin_dir = local.bin_dir
  }

  provisioner "local-exec" {
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --delete --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }
}
