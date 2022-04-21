locals {
  name          = "ibmcloud-operator"
  bin_dir       = module.setup_clis.bin_dir
  operator_yaml_dir = "${path.cwd}/.tmp/${local.name}/chart/${local.name}"
  secret_dir = "${path.cwd}/.tmp/${local.name}/secrets"
  values_content = {
    global = {
      clusterType = "ocp4"
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
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}' --cascadingDelete=false"

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
