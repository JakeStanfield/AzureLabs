// =====================================================================
// Public Standard Load Balancer for the Keystone web tier.
//
// LAB CHOICES (document in writeup):
//   - Standard LB (Layer 4). Production: Application Gateway v2 + WAF
//     (TLS termination, cookie affinity, OWASP protection for PII).
//   - HTTP 80 only. Production: HTTPS - claims data never travels in clear text.
//   - Outbound via LB outbound rules. Production: NAT Gateway (auto-scaling
//     SNAT, Microsoft's recommended pattern, takes precedence over outbound rules).
// =====================================================================
param location string
param tags object
param lbName string = 'lbe-keystone-web'

@description('DNS label -> <label>.<region>.cloudapp.azure.com, handy for testing.')
param dnsLabel string

@description('Default = 5-tuple hash (no affinity). SourceIP = client IP affinity (legacy in-memory sessions).')
@allowed([
  'Default'
  'SourceIP'
])
param loadDistribution string = 'Default'

@description('SNAT ports per backend VM for outbound rules. Multiple of 8; 64,000 per frontend IP total.')
param outboundPortsPerVm int = 10000

// ---------------------------------------------------------------------
// Zone-redundant frontend IP - survives the loss of any single zone,
// matching VMs spread across zones 1 and 2.
// ---------------------------------------------------------------------
resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${lbName}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabel
    }
  }
}

var feName = 'fe-public'
var poolName = 'be-web'
var probeName = 'probe-http'

resource lb 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: lbName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: feName
        properties: {
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: poolName
      }
    ]
    probes: [
      {
        // HTTP probe: healthy only if IIS actually returns 200 on "/".
        // A TCP probe would pass even if IIS were throwing errors.
        // Probes come from 168.63.129.16 - allowed by the NSG default
        // rule AllowAzureLoadBalancerInBound.
        name: probeName
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          probeThreshold: 1
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'rule-http'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, feName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, poolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, probeName)
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          loadDistribution: loadDistribution
          enableFloatingIP: false
          enableTcpReset: true
          idleTimeoutInMinutes: 4
          // Required when an outbound rule exists: outbound SNAT is handled
          // ONLY by the outbound rule below, never implicitly by this rule.
          disableOutboundSnat: true
        }
      }
    ]
    outboundRules: [
      {
        // Gives the private-only VMs internet egress (Windows Update,
        // activation, Entra sign-in) through the LB's public IP.
        name: 'outbound-web'
        properties: {
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, feName)
            }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, poolName)
          }
          protocol: 'All'
          allocatedOutboundPorts: outboundPortsPerVm
          enableTcpReset: true
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

output lbId string = lb.id
output backendPoolId string = lb.properties.backendAddressPools[0].id
output publicIp string = pip.properties.ipAddress
output fqdn string = pip.properties.dnsSettings.fqdn
