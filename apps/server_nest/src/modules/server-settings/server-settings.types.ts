export interface ServerSettingsView {
  serverName: string;
  registrationEnabled: boolean;
  defaultLocale: string;
  maxUploadSizeMb: number;
}

export interface ServerDiscoverySettings {
  instanceId: string;
  serverName: string;
  registrationEnabled: boolean;
}

export interface UpdateServerSettingsInput {
  registrationEnabled: boolean;
}
