export type ServerMetadata = {
  name: string;
  version: string;
  apiBaseUrl: string;
  websocketUrl: string;
  registrationEnabled: boolean;
  serverMode: 'self_hosted' | 'public';
  supportedSystems: string[];
  apiVersion: string;
  features: string[];
};
