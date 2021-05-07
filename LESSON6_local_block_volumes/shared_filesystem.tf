resource "oci_file_storage_mount_target" "FoggyKitchenMountTarget" {
  availability_domain = var.availablity_domain_name == "" ? lookup(data.oci_identity_availability_domains.ADs.availability_domains[0], "name") : var.availablity_domain_name
  compartment_id = oci_identity_compartment.FoggyKitchenCompartment.id
  subnet_id = oci_core_subnet.FoggyKitchenWebSubnet.id
  ip_address = var.MountTargetIPAddress
  display_name = "FoggyKitchenMountTarget"
}

resource "oci_file_storage_export_set" "FoggyKitchenExportset" {
  mount_target_id = oci_file_storage_mount_target.FoggyKitchenMountTarget.id
  display_name = "FoggyKitchenExportset"
}

resource "oci_file_storage_file_system" "FoggyKitchenFilesystem" {
  availability_domain = var.availablity_domain_name == "" ? lookup(data.oci_identity_availability_domains.ADs.availability_domains[0], "name") : var.availablity_domain_name
  compartment_id = oci_identity_compartment.FoggyKitchenCompartment.id
  display_name = "FoggyKitchenFilesystem"
}

resource "oci_file_storage_export" "FoggyKitchenExport" {
  export_set_id = oci_file_storage_mount_target.FoggyKitchenMountTarget.export_set_id
  file_system_id = oci_file_storage_file_system.FoggyKitchenFilesystem.id
  path = "/sharedfs"
}


resource "null_resource" "FoggyKitchenWebserver1SharedFilesystem" {
 depends_on = [oci_core_instance.FoggyKitchenWebserver1,oci_core_instance.FoggyKitchenBastionServer,oci_file_storage_export.FoggyKitchenExport]

 provisioner "remote-exec" {
   connection {
                type                = "ssh"
                user                = "opc"
                host                = data.oci_core_vnic.FoggyKitchenWebserver1_VNIC1.private_ip_address
                private_key         = tls_private_key.public_private_key_pair.private_key_pem
                script_path         = "/home/opc/myssh.sh"
                agent               = false
                timeout             = "10m"
                bastion_host        = data.oci_core_vnic.FoggyKitchenBastionServer_VNIC1.public_ip_address
                bastion_port        = "22"
                bastion_user        = "opc"
                bastion_private_key = tls_private_key.public_private_key_pair.private_key_pem
        }
  inline = [
            "echo '== Start of null_resource.FoggyKitchenWebserver1SharedFilesystem'", 
            "sudo /bin/su -c \"yum install -y -q nfs-utils\"",
            "sudo /bin/su -c \"mkdir -p /sharedfs\"",
            "sudo /bin/su -c \"echo '${var.MountTargetIPAddress}:/sharedfs /sharedfs nfs rsize=8192,wsize=8192,timeo=14,intr 0 0' >> /etc/fstab\"",
            "sudo /bin/su -c \"mount /sharedfs\"",
            "echo '== End of null_resource.FoggyKitchenWebserver1SharedFilesystem'"
            ]
  }

}

resource "null_resource" "FoggyKitchenWebserver2SharedFilesystem" {
 depends_on = [oci_core_instance.FoggyKitchenWebserver2,oci_core_instance.FoggyKitchenBastionServer,oci_file_storage_export.FoggyKitchenExport]

 provisioner "remote-exec" {
   connection {
                type                = "ssh"
                user                = "opc"
                host                = data.oci_core_vnic.FoggyKitchenWebserver2_VNIC1.private_ip_address
                private_key         = tls_private_key.public_private_key_pair.private_key_pem
                script_path         = "/home/opc/myssh.sh"
                agent               = false
                timeout             = "10m"
                bastion_host        = data.oci_core_vnic.FoggyKitchenBastionServer_VNIC1.public_ip_address
                bastion_port        = "22"
                bastion_user        = "opc"
                bastion_private_key = tls_private_key.public_private_key_pair.private_key_pem
        }
  inline = [
            "echo '== Start of null_resource.FoggyKitchenWebserver2SharedFilesystem'",
            "sudo /bin/su -c \"yum install -y -q nfs-utils\"",
            "sudo /bin/su -c \"mkdir -p /sharedfs\"",
            "sudo /bin/su -c \"echo '${var.MountTargetIPAddress}:/sharedfs /sharedfs nfs rsize=8192,wsize=8192,timeo=14,intr 0 0' >> /etc/fstab\"",
            "sudo /bin/su -c \"mount /sharedfs\"",
            "echo '== End of null_resource.FoggyKitchenWebserver2SharedFilesystem'"
            ]
  }

}
