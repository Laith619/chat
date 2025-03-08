import { randomBytes } from 'crypto';
import { NextAuthOptions } from 'next-auth';
import { OAuthConfig } from 'next-auth/providers';

const getRandomState = () => randomBytes(32).toString('hex');

export interface CasdoorConfig {
  id: string;
  clientId: string;
  clientSecret: string;
  name?: string;
  issuer: string;
  authorizationUrl?: string;
  tokenUrl?: string;
  userInfoUrl?: string;
}

export const CasdoorProvider = (options: CasdoorConfig): OAuthConfig<any> => {
  const { id, name, issuer, clientId, clientSecret } = options;

  const authorizationUrl = options.authorizationUrl || `${issuer}/login/oauth/authorize`;
  const tokenUrl = options.tokenUrl || `${issuer}/api/login/oauth/access_token`;
  const userInfoUrl = options.userInfoUrl || `${issuer}/api/userinfo`;

  console.log('Casdoor Configuration:', {
    id,
    issuer,
    clientId,
    authorizationUrl,
    tokenUrl,
    userInfoUrl,
    wellKnown: `${issuer}/.well-known/openid-configuration`,
  });

  return {
    id,
    name: name || 'Casdoor',
    type: 'oauth',
    wellKnown: `${issuer}/.well-known/openid-configuration`,
    authorization: {
      url: authorizationUrl,
      params: { 
        scope: 'openid profile email', 
        state: getRandomState(),
        response_type: 'code',
      },
    },
    token: {
      url: tokenUrl,
    },
    userinfo: {
      url: userInfoUrl,
    },
    clientId,
    clientSecret,
    profile(profile) {
      console.log('Casdoor profile response:', JSON.stringify(profile, null, 2));
      
      return {
        id: profile.sub || profile.id,
        name: profile.name,
        email: profile.email,
        image: profile.picture || profile.avatar,
      };
    },
  };
};

export const authOptions: NextAuthOptions = {
  providers: [
    CasdoorProvider({
      id: 'casdoor',
      clientId: process.env.AUTH_CASDOOR_ID || '',
      clientSecret: process.env.AUTH_CASDOOR_SECRET || '',
      issuer: process.env.AUTH_CASDOOR_ISSUER || 'http://localhost:8000',
    }),
  ],
  callbacks: {
    async signIn({ user, account, profile, email, credentials }) {
      console.log('[Auth] Sign in attempt:', { 
        userId: user.id,
        email: user.email,
        accountType: account?.type,
        providerAccountId: account?.providerAccountId
      });
      return true;
    },
    async jwt({ token, account, profile }) {
      // Initial sign in
      if (account && profile) {
        console.log('[Auth] JWT callback with account:', { 
          provider: account.provider,
          tokenType: account.token_type,
          providerId: account.providerAccountId 
        });
      }
      return token;
    },
    async session({ session, token, user }) {
      console.log('[Auth] Session callback:', { 
        userId: token.sub,
        sessionExpiry: session.expires 
      });
      return session;
    },
  },
  session: {
    strategy: 'jwt',
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
  pages: {
    signIn: '/signin',
    error: '/auth/error',
  },
  debug: true,  // Always enable debug mode to help diagnose issues
};
