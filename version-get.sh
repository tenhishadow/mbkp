function fn_check_ros_version () {
  awk -F"[:.]" '/version/{gsub(/ /,""); print $2}' "${1}"
}

fn_check_ros_version temp-input
