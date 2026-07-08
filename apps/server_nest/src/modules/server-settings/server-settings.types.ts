export interface ServerSettingsView {
  serverName: string;
  registrationEnabled: boolean;
  defaultLocale: string;
  maxUploadSizeMb: number;
}

export interface UpdateServerSettingsInput {
  registrationEnabled: boolean;
}
