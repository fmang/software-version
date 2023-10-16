require 'software_version/version'

module SoftwareVersion
end

# Convert the argument into a SoftwareVersion::Version.
def SoftwareVersion(version)
  SoftwareVersion::Version(version)
end
