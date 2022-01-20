function fn_check_ros_version () {
  ROS_VERSION=$( awk -F '[:.]' '/version/{gsub(/ /,""); print $2}' "${1}" )

  echo "...checking ${ROS_VERSION}"

  case ${ROS_VERSION} in
    "6")
    echo "version ${ROS_VERSION} is supported"
    echo "export command will be:"
    echo "export terse"
    ;;
    "7")
    echo "version ${ROS_VERSION} is supported"
    echo "export command will be:"
    echo "export terse show-sensitive"
    ;;
    "*")
    echo "version ${ROS_VERSION} is NOT supported"
    ;;
  esac
}


for i in temp-v6 temp-v7 temp-v7x temp-v8 temp-v9; do

  echo "file $i"
  fn_check_ros_version $i
  echo ""
done

