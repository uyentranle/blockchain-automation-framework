apiVersion: flux.weave.works/v1beta1
kind: HelmRelease
metadata:
  name: {{ component_name }}
  namespace: {{ component_ns }}
  annotations:
    flux.weave.works/automated: "false"
spec:
  releaseName: {{ component_name }}
  chart:
    git: {{ git_url }}
    ref: {{ git_branch }}
    path: {{ charts_dir }}/node_tessera  
  values:
    replicaCount: 1
    metadata:
      namespace: {{ component_ns }}
      labels:
    images:
      node: quorumengineering/quorum:{{ network.version }}
      alpineutils: {{ network.docker.url }}/alpine-utils:1.0
      tessera: quorumengineering/tessera:{{ network.config.tm_version }}
      busybox: busybox
      mysql: mysql/mysql-server:5.7
    node:
      name: {{ peer.name }}
      consensus: {{ consensus }}
      mountPath: /etc/quorum/qdata
      imagePullSecret: regcred
      keystore: keystore_1
      servicetype: ClusterIP
      ports:
        rpc: {{ peer.rpc.port }}
        raft: {{ peer.raft.port }}
        tm: {{ peer.transaction_manager.port }}
        quorum: {{ peer.p2p.port }}
        db: {{ peer.db.port }}
      dbname: demodb
      mysqluser: demouser
      mysqlpassword: password
    vault:
      address: {{ vault.url }}
      secretprefix: secret/{{ component_ns }}/crypto/{{ peer.name }}
      serviceaccountname: vault-auth
      keyname: quorum
      tm_keyname: transaction
      role: vault-role
      authpath: quorum{{ name }}
    tessera:
      dburl: "jdbc:mysql://localhost:3306/demodb"
      dbusername: $username
      dbpassword: $password
{% if network.config.tm_tls == 'strict' %}
      url: "https://localhost:9001"
{% else %}
      url: "http://localhost:9001"
{% endif %}
      othernodes:
{% for tm_node in network.config.tm_nodes %}
        - url: {{ tm_node }}
{% endfor %}
      tls: "{{ network.config.tm_tls | upper }}"
      trust: "{{ network.config.tm_trust | upper }}"
    genesis: {{ genesis }}
    staticnodes:
{% if network.config.consensus == 'ibft' %}
{% for enode in enode_data_list %}
      - enode://{{ enode.enodeval }}@{{ enode.peer_name }}.{{ external_url }}:{{ enode.p2p_ambassador }}?discport=0
{% endfor %}
{% endif %}
{% if network.config.consensus == 'raft' %}
{% for enode in enode_data_list %}
      - enode://{{ enode.enodeval }}@{{ enode.peer_name }}.{{ external_url }}:{{ enode.p2p_ambassador }}?discport=0&raftport={{ enode.raft_ambassador }}
{% endfor %}
{% endif %}
    proxy:
      provider: "ambassador"
      external_url: {{ name }}.{{ external_url }}
      portTM: {{ peer.transaction_manager.ambassador }}
      rpcport: {{ peer.rpc.ambassador }}
      quorumport: {{ peer.p2p.ambassador }}
{% if network.config.consensus == 'raft' %}  
      portRaft: {{ peer.raft.ambassador }}
{% endif %}
    storage:
      storageclassname: {{ storageclass_name }}
      storagesize: 1Gi
      dbstorage: 1Gi
