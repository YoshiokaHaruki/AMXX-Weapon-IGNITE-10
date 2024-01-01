/**
 * Weapon by xUnicorn (t3rkecorejz) 
 *
 * Thanks a lot:
 *
 * Chrescoe1 & batcoh (Phenix) — First base code
 * KORD_12.7 & wellasgood— I'm taken some functions from this authors
 */

new const PluginName[ ] =					"[ZP] Grenade: IGNITE-10";
new const PluginVersion[ ] =				"1.1";
new const PluginAuthor[ ] =					"Yoshioka Haruki";

/* ~ [ Includes ] ~ */
#include <amxmodx>
#include <fakemeta_util>
#include <hamsandwich>
#include <xs>
#include <zombieplague>
#include <reapi> // If you are not using ReAPI, delete or comment out this line

#if !defined _reapi_included
	/**
	 * For compile and use the plugin, download latest version of this include.
	 * Download: https://gist.github.com/YoshiokaHaruki/bcc9c6dbc6e23c69ea53d04c72a03cbd
	 */
	#tryinclude <non_reapi_support>
#endif

#if !defined DMG_GRENADE
	#define DMG_GRENADE						(1<<24)
#endif

/**
 * Automatically precache sounds from the model
 * 
 * If you have ReHLDS installed, you do not need this setting with a server cvar
 * `sv_auto_precache_sounds_in_models 1`
 */
#define PrecacheSoundsFromModel

/* ~ [ Extra-Items ] ~ */
new const ExtraItem_Name[ ] =				"Grenade: IGNITE-10";
const ExtraItem_Cost =						0;

/* ~ [ Weapon Settings ] ~ */
const WeaponUnicalIndex =					31122023;
new const WeaponReference[ ] =				"weapon_hegrenade";
new const WeaponListDir[ ] =				"x_re/weapon_ignitebomb";
new const WeaponNative[ ] =					"zp_give_user_ignitebomb";
new const WeaponModelView[ ] =				"models/x_re/v_ignitebomb.mdl";
new const WeaponModelPlayer[ ] =			"models/x_re/p_ignitebomb.mdl";
new const WeaponModelWorld[ ] =				"models/x_re/w_ignitebomb.mdl";
new const WeaponSounds[ ][ ] = {
	"weapons/ignitebomb_exp.wav",
	"weapons/ignitebomb_exp2.wav"
};

const WeaponModelWorldBody =				0;
const WeaponMaxAmmo =						2;

/**
 * All settings go in turn.
 * 
 * First: Grenade (When you throw a grenade)
 * Second: Impact (When you detonate a grenade in your hands [ATTACK2])
 */
new const WeaponExplodeSprites[ ][ ] = {
	"sprites/x_re/ef_ignite_bomb.spr",
	"sprites/x_re/muzzleflash340.spr"
};
new const any: WeaponExplodeSpriteSettings[ ][ ] = {
	/**
	 * Z Offset: How many units to raise the sprite up
	 * Scale: Sprite size
	 * Framerate: Sprite frame rate
	 * 
	 * NB! Frame rate value...
	 * 
	 * The Framerate value indicates how many frames will be played in 1 second.
	 * If you need the sprite to be displayed for 1 second, you need to specify a value such
	 * as how many frames the sprite contains.
	 * 
	 * To specify the display time, there is a formula for this: (Frames * Time)
	 */
	{ 64.0, 12, 34 }, // Grenade
	{ 0.0, 6, 30 } // Impact
};
new const Float: WeaponExplodeDamage[ ] = {
	1500.0, 750.0
}
new const Float: WeaponExplodeRadius[ ] = {
	150.0, 75.0
}
new const Float: WeaponExplodeKnockBack[ ] = {
	250.0, 1250.0
};
const WeaponExplodeDamageType =				DMG_GRENADE;

/* ~ [ Entity: Ignite Effect ] ~ */
new const EntityEffectReference[ ] =		"info_target";
new const EntityEffectClassName[ ] =		"ef_ignitebomb";
new const EntityEffectModel[ ] =			"models/x_re/ef_ignitebomb.mdl";
const Float: EntityEffectLifeTime =			1.0;
const Float: EntityEffectAnimationFPS =		30.0;
const EntityEffectMaxSkins =				15;

/* ~ [ Weapon Animations ] ~ */
enum {
	WeaponAnim_Draw = 3,
	WeaponAnim_BMode
};

const Float: WeaponAnim_Draw_Time =			1.0;
const Float: WeaponAnim_BMode_Time =		1.0;

/* ~ [ Glow Effect ] ~ */
#define GrenadeHasGlowEffect
#if defined GrenadeHasGlowEffect
	new const Float: GlowEffectColor[ 3 ] =	{ 255.0, 64.0, 64.0 };
	const Float: GlowEffectThickness =		24.0;
#endif

/* ~ [ Trail Effect ] ~ */
#define GrenadeHasTrailEffect
#if defined GrenadeHasTrailEffect
	new const TrailEffectSprite[ ] =		"sprites/laserbeam.spr";
	new const TrailEffectColor[ 3 ] =		{ 255, 64, 64 };
	const TrailEffectLife =					10;
	const TrailEffectWidth =				10;
	const TrailEffectBrightness =			200;
#endif

/* ~ [ Params ] ~ */
#if AMXX_VERSION_NUM <= 182
	new MaxClients;
	new Float: NULL_VECTOR[ 3 ];
#endif

#if !defined _reapi_included && defined WeaponListDir
	new gl_iMsgHook_WeaponList;
	new gl_FM_Hook_RegUserMsg_Post;
	new gl_aWeaponListData[ 8 ];
#endif

new gl_iItemId;
new gl_iDecalIndex_Scorch1;
new Float: EntityEffectNextThink;

enum eModelIndex {
#if defined GrenadeHasTrailEffect
	ModelIndex_BeamFollow,
#endif
	ModelIndex_ExplodeBomb,
	ModelIndex_ExplodeImpact
};
new gl_iszModelIndex[ eModelIndex ];

enum (<<= 1) {
	WeaponState_BMode = 1,
	WeaponState_BMode_Post
};

enum {
	Sprite_ZOffset = 0,
	Sprite_Scale,
	Sprite_Framerate
};

/* ~ [ Macroses ] ~ */
#if !defined Vector3
	#define Vector3(%0)						Float: %0[ 3 ]
#endif

#if AMXX_VERSION_NUM <= 182
	#define OBS_IN_EYE						4
	#define MAX_PLAYERS						32
	#define MAX_NAME_LENGTH					32

	#define write_coord_f(%0)				engfunc( EngFunc_WriteCoord, %0 )
	stock message_begin_f( const dest, const msg_type, const Vector3( origin ) = { 0.0, 0.0, 0.0 }, const player = 0 )
		engfunc( EngFunc_MessageBegin, dest, msg_type, origin, player );
#endif

#define BIT_ADD(%0,%1)						( %0 |= %1 )
#define BIT_VALID(%0,%1)					( ( %0 & %1 ) == %1 )

#define IsUserValid(%0)						bool: ( 0 < %0 <= MaxClients )
#define IsNullString(%0)					bool: ( %0[ 0 ] == EOS )
#define IsCustomWeapon(%0,%1)				bool: ( get_entvar( %0, var_impulse ) == %1 )
#define GetWeaponState(%0)					get_member( %0, m_Weapon_iWeaponState )
#define SetWeaponState(%0,%1)				set_member( %0, m_Weapon_iWeaponState, %1 )
#define GetWeaponAmmoType(%0)				get_member( %0, m_Weapon_iPrimaryAmmoType )
#define GetWeaponAmmo(%0,%1)				get_member( %0, m_rgAmmo, %1 )
#define SetWeaponAmmo(%0,%1,%2)				set_member( %0, m_rgAmmo, %1, %2 )
#define AdjustDamage(%0,%1)					( %0 * ( 1.0 - floatmin( %1, 0.7 ) ) )
#define IsGrenadeOnPullPin(%0)				bool: ( Float: get_member( %0, m_flStartThrow ) != 0.0 || Float: get_member( %0, m_flReleaseThrow ) != -1.0 )

/* ~ [ AMX Mod X ] ~ */
public plugin_natives( )
{
	register_native( WeaponNative, "native_give_user_weapon" );
}

public plugin_precache( )
{
	/* -> Precache Models <- */
	precache_model_ex( WeaponModelView );
	precache_model_ex( WeaponModelPlayer );
	precache_model_ex( WeaponModelWorld );
	precache_model_ex( EntityEffectModel );

	/* -> Precache Sounds <- */
	for ( new i; i < sizeof WeaponSounds; i++ )
		precache_sound_ex( WeaponSounds[ i ] );

#if defined PrecacheSoundsFromModel
	UTIL_PrecacheSoundsFromModel( WeaponModelView );
#endif

#if defined WeaponListDir
	/* -> Hook Weapon <- */
	register_clcmd( WeaponListDir, "ClientCommand__HookWeapon" );

	/* -> Precache WeaponList <- */
	UTIL_PrecacheWeaponList( WeaponListDir );

	#if !defined _reapi_included
		/* -> Get MessageId < - */
		new iMsgId_Weaponlist = get_user_msgid( "WeaponList" );

		if ( !iMsgId_Weaponlist )
			gl_FM_Hook_RegUserMsg_Post = register_forward( FM_RegUserMsg, "FM_Hook_RegUserMsg_Post", true );
		else
			gl_iMsgHook_WeaponList = register_message( iMsgId_Weaponlist, "MsgHook_WeaponList" );
	#endif
#endif

	/* -> Model Index <- */
#if defined GrenadeHasTrailEffect
	gl_iszModelIndex[ ModelIndex_BeamFollow ] = precache_model( TrailEffectSprite );
#endif
	gl_iszModelIndex[ ModelIndex_ExplodeBomb ] = precache_model_ex( WeaponExplodeSprites[ 0 ] );
	gl_iszModelIndex[ ModelIndex_ExplodeImpact ] = precache_model_ex( WeaponExplodeSprites[ 1 ] );

	/* -> Decal Index <- */
	gl_iDecalIndex_Scorch1 = engfunc( EngFunc_DecalIndex, "{scorch1" );
}

public plugin_init( )
{
	register_plugin( PluginName, PluginVersion, PluginAuthor );

#if defined _reapi_included
	/* -> ReGameDLL <- */
	RegisterHookChain( RG_CBasePlayer_ThrowGrenade, "RG_CBasePlayer__ThrowGrenade_Post", true );
#else
	/* -> Fakemeta <- */
	register_forward( FM_SetModel, "FM_Hook_SetModel_Post", true );
#endif

	/* -> HamSandwich: Weapon <- */
	RegisterHam( Ham_Item_Holster, WeaponReference, "Ham_CWeapon_Holster_Post", true );
	RegisterHam( Ham_Item_Deploy, WeaponReference, "Ham_CWeapon_Deploy_Post", true );
	RegisterHam( Ham_Item_PostFrame, WeaponReference, "Ham_CWeapon_PostFrame_Pre", false );
#if defined WeaponListDir
	RegisterHam( Ham_Item_AddToPlayer, WeaponReference, "Ham_CWeapon_AddToPlayer_Post", true );
#endif
	RegisterHam( Ham_Weapon_SecondaryAttack, WeaponReference, "Ham_CWeapon_SecondaryAttack_Pre", false );

	/* -> HamSandwich: Grenade Entity <- */
	new const GrenadeReference[ ] = "grenade";
	RegisterHam( Ham_Think, GrenadeReference, "Ham_CGrenade_Think_Pre", false );
	RegisterHam( Ham_Touch, GrenadeReference, "Ham_CGrenade_Touch_Post", true );

#if !defined _reapi_included
	/* -> HamSandwich: Entity <- */
	RegisterHam( Ham_Think, EntityEffectReference, "CEffect__Think", true );
#endif

	/* -> Register on Extra-Items <- */
	gl_iItemId = zp_register_extra_item( ExtraItem_Name, ExtraItem_Cost, ZP_TEAM_HUMAN );

#if !defined _reapi_included && defined WeaponListDir
	/* -> Unregister Forwards <- */
	if ( gl_FM_Hook_RegUserMsg_Post )
		unregister_forward( FM_RegUserMsg, gl_FM_Hook_RegUserMsg_Post, true );

	unregister_message( get_user_msgid( "WeaponList" ), gl_iMsgHook_WeaponList );
#endif
}

public plugin_cfg( )
{
	/* -> Other <- */
#if AMXX_VERSION_NUM <= 182
	#if defined _reapi_included
		MaxClients = get_member_game( m_nMaxPlayers );
	#else
		MaxClients = get_maxplayers( );
	#endif
#endif
 
	EntityEffectNextThink = EntityEffectLifeTime / EntityEffectAnimationFPS;
}

public bool: native_give_user_weapon( const iPlugin, const iParams )
{
	enum { arg_player = 1 };

	new pPlayer = get_param( arg_player );
	if ( !is_user_connected( pPlayer ) )
	{
		log_error( AMX_ERR_NATIVE, "[AMXX] Invalid Player (Id: %i)", pPlayer );
		return false;
	}

	return CPlayer__GiveGrenade( pPlayer );
}

public ClientCommand__HookWeapon( const pPlayer )
{
	engclient_cmd( pPlayer, WeaponReference );
	return PLUGIN_HANDLED;
}

/* ~ [ Zombie Plague ] ~ */
public zp_extra_item_selected( pPlayer, iItemId )
{
	if ( iItemId != gl_iItemId )
		return PLUGIN_HANDLED;

	return CPlayer__GiveGrenade( pPlayer ) ? PLUGIN_CONTINUE : ZP_PLUGIN_HANDLED;
}

#if defined _reapi_included
	/* ~ [ ReGameDLL ] ~ */
	public RG_CBasePlayer__ThrowGrenade_Post( const pPlayer, const pInflictor )
	{
		if ( is_nullent( pInflictor ) || !IsCustomWeapon( pInflictor, WeaponUnicalIndex ) )
			return;

		new pGrenade = GetHookChainReturn( ATYPE_INTEGER );
		if ( is_nullent( pGrenade ) )
			return;

		CGrenade__UpdateProperties( pGrenade );
	}
#else
	/* ~ [ Messages ] ~ */
	#if defined WeaponListDir
		public MsgHook_WeaponList( const iMsgId, const iMsgDest, const pReceiver )
		{
			// Method by KORD_12.7
			if ( !pReceiver )
			{
				new szWeaponName[ MAX_NAME_LENGTH ];
				get_msg_arg_string( 1, szWeaponName, charsmax( szWeaponName ) );

				if ( !strcmp( szWeaponName, WeaponReference ) )
				{
					for ( new i, a = sizeof gl_aWeaponListData; i < a; i++ )
						gl_aWeaponListData[ i ] = get_msg_arg_int( i + 2 );
				}
			}
		}
	#endif

	/* ~ [ Fakemeta ] ~ */
	#if defined WeaponListDir
		public FM_Hook_RegUserMsg_Post( const szName[ ] )
		{
			// Method by wellasgood
			if ( strcmp( szName, "WeaponList" ) == 0 )
				gl_iMsgHook_WeaponList = register_message( get_orig_retval( ), "MsgHook_WeaponList" );
		}
	#endif

	public FM_Hook_SetModel_Post( const pEntity, const szModel[ ] )
	{
		if ( is_nullent( pEntity ) )
			return;

		if ( !FClassnameIs( pEntity, "grenade" ) )
			return;

		new pOwner = get_entvar( pEntity, var_owner );
		if ( !IsUserValid( pOwner ) )
			return;

		new pActiveItem = get_member( pOwner, m_pActiveItem );
		if ( is_nullent( pActiveItem ) || !IsCustomWeapon( pActiveItem, WeaponUnicalIndex ) )
			return;

		CGrenade__UpdateProperties( pEntity );
	}
#endif

/* ~ [ HamSandwich ] ~ */
public Ham_CWeapon_Holster_Post( const pItem )
{
	if ( is_nullent( pItem ) )
		return;

	new pPlayer = get_member( pItem, m_pPlayer );
	if ( !IsUserValid( pPlayer ) )
		return;

	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	SetWeaponState( pItem, 0 );

	set_member( pItem, m_Weapon_flTimeWeaponIdle, 1.0 );
	set_member( pPlayer, m_flNextAttack, 1.0 );
}

public Ham_CWeapon_Deploy_Post( const pItem )
{
	if ( is_nullent( pItem ) || !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	new pPlayer = get_member( pItem, m_pPlayer );
	if ( !IsUserValid( pPlayer ) )
		return;

	set_entvar( pPlayer, var_viewmodel, WeaponModelView );
	set_entvar( pPlayer, var_weaponmodel, WeaponModelPlayer );

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, WeaponAnim_Draw );

	set_member( pPlayer, m_flNextAttack, WeaponAnim_Draw_Time - 0.2 );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Draw_Time );
}

public Ham_CWeapon_PostFrame_Pre( const pItem )
{
	if ( is_nullent( pItem ) || !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return HAM_IGNORED;

	static bitsWeaponState;
	if ( ( bitsWeaponState = GetWeaponState( pItem ) ) )
	{
		static pPlayer; pPlayer = get_member( pItem, m_pPlayer );
		if ( !IsUserValid( pPlayer ) )
			return HAM_IGNORED;

		if ( BIT_VALID( bitsWeaponState, WeaponState_BMode ) )
		{
			static iAmmoType; if ( !iAmmoType ) iAmmoType = GetWeaponAmmoType( pItem );
			static iAmmo; iAmmo = GetWeaponAmmo( pPlayer, iAmmoType );

			if ( BIT_VALID( bitsWeaponState, WeaponState_BMode_Post ) )
			{
				if ( !iAmmo )
				{
					UTIL_StripWeaponByIndex( pPlayer, pItem );
					return HAM_SUPERCEDE;
				}

				SetWeaponState( pItem, 0 );
				ExecuteHamB( Ham_Item_Deploy, pItem );
			}
			else
			{
				static Vector3( vecOrigin ); UTIL_GetEyePosition( pPlayer, vecOrigin );
				static Vector3( vecAiming ); UTIL_GetVectorAiming( pPlayer, vecAiming );

				xs_vec_mul_scalar( vecAiming, 75.0, vecAiming );
				xs_vec_add( vecOrigin, vecAiming, vecOrigin );

				CEffect__SpawnEntity( pPlayer );

				set_entvar( pItem, var_classname, "grenade" );
				CGrenade__Explode( pItem, pPlayer, vecOrigin, true );
				set_entvar( pItem, var_classname, WeaponReference );

				BIT_ADD( bitsWeaponState, WeaponState_BMode_Post );
				SetWeaponState( pItem, bitsWeaponState );
				SetWeaponAmmo( pPlayer, --iAmmo, iAmmoType );

				set_member( pPlayer, m_flNextAttack, 0.5 );
			}
		}
	}

	return HAM_IGNORED;
}

#if defined WeaponListDir
	public Ham_CWeapon_AddToPlayer_Post( const pItem, const pPlayer )
	{
		if ( is_nullent( pItem ) )
			return;

	#if defined _reapi_included
		if ( IsCustomWeapon( pItem, WeaponUnicalIndex ) && get_entvar( pItem, var_owner ) <= 0 )
		{
			rg_set_iteminfo( pItem, ItemInfo_pszName, WeaponListDir );
			rg_set_iteminfo( pItem, ItemInfo_iMaxAmmo1, WeaponMaxAmmo );
		}

		UTIL_WeaponList( MSG_ONE, pPlayer, pItem );
	#else
		if ( IsCustomWeapon( pItem, WeaponUnicalIndex ) )
			UTIL_WeaponList( MSG_ONE, pPlayer, WeaponListDir );
		else if ( IsCustomWeapon( pItem, 0 ) )
			UTIL_WeaponList( MSG_ONE, pPlayer, WeaponReference );
	#endif
	}
#endif

public Ham_CWeapon_SecondaryAttack_Pre( const pItem )
{
	if ( is_nullent( pItem ) || !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return HAM_IGNORED;

	new pPlayer = get_member( pItem, m_pPlayer );
	if ( !IsUserValid( pPlayer ) )
		return HAM_IGNORED;

	if ( !GetWeaponAmmo( pPlayer, GetWeaponAmmoType( pItem ) ) )
		return HAM_SUPERCEDE;

	if ( IsGrenadeOnPullPin( pItem ) )
		return HAM_SUPERCEDE;

#if defined _reapi_included
	rg_set_animation( pPlayer, PLAYER_ATTACK1 );
#else
	new szPlayerAnim[ 32 ]; formatex( szPlayerAnim, charsmax( szPlayerAnim ), "%s_shoot_grenade", get_entvar( pPlayer, var_flags ) & FL_DUCKING ? "crouch" : "ref" );
	UTIL_PlayerAnimation( pPlayer, szPlayerAnim );
#endif

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, WeaponAnim_BMode );

	SetWeaponState( pItem, GetWeaponState( pItem )|WeaponState_BMode );

	set_member( pPlayer, m_flNextAttack, 0.1 );
	set_member( pItem, m_flStartThrow, 0.0 );
	set_member( pItem, m_flReleaseThrow, -1.0 );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_BMode_Time );
	set_member( pItem, m_Weapon_flNextPrimaryAttack, WeaponAnim_BMode_Time );
	set_member( pItem, m_Weapon_flNextSecondaryAttack, WeaponAnim_BMode_Time );

	return HAM_SUPERCEDE;
}

public Ham_CGrenade_Think_Pre( const pGrenade )
{
	if ( is_nullent( pGrenade ) || !IsCustomWeapon( pGrenade, WeaponUnicalIndex ) )
		return HAM_IGNORED;

	static pOwner; pOwner = get_entvar( pGrenade, var_owner );
	if ( !is_user_connected( pOwner ) || zp_get_user_zombie( pOwner ) )
	{
		UTIL_KillEntity( pGrenade );
		return HAM_SUPERCEDE;
	}

	new Vector3( vecOrigin ); get_entvar( pGrenade, var_origin, vecOrigin );
	CGrenade__Explode( pGrenade, pOwner, vecOrigin, false );

	UTIL_KillEntity( pGrenade );
	return HAM_SUPERCEDE;
}

public Ham_CGrenade_Touch_Post( const pGrenade, const pTouch )
{
	if ( is_nullent( pGrenade ) || !IsCustomWeapon( pGrenade, WeaponUnicalIndex ) )
		return;

	set_entvar( pGrenade, var_nextthink, get_gametime( ) );
}

/* ~ [ Other ] ~ */
public bool: CPlayer__GiveGrenade( const pPlayer )
{
	if ( !is_user_alive( pPlayer ) )
		return false;

	new pGrenade = UTIL_GetItemByName( pPlayer, WeaponReference );
	if ( !is_nullent( pGrenade ) )
	{
		if ( IsCustomWeapon( pGrenade, WeaponUnicalIndex ) )
		{
			if ( GetWeaponAmmo( pPlayer, GetWeaponAmmoType( pGrenade ) ) >= WeaponMaxAmmo )
			{
				client_print( pPlayer, print_center, "*** You can't buy more than %i grenades ***", WeaponMaxAmmo );
				return false;
			}
			else
			{
				ExecuteHamB( Ham_GiveAmmo, pPlayer, 1, "HEGrenade", WeaponMaxAmmo );
				rh_emit_sound2( pPlayer, 0, CHAN_ITEM, "items/9mmclip1.wav" );
			}
		}
		else
		{
			client_print( pPlayer, print_center, "*** Do you already have any kind of combat grenade ***" );
			return false;
		}
	}
	else
	{
		pGrenade = rg_give_custom_item( pPlayer, WeaponReference, GT_APPEND, WeaponUnicalIndex );
		if ( is_nullent( pGrenade ) || !IsCustomWeapon( pGrenade, WeaponUnicalIndex ) )
			return false;

		SetWeaponAmmo( pPlayer, WeaponMaxAmmo, GetWeaponAmmoType( pGrenade ) );
	}

	return true;
}

public CGrenade__Explode( const pInflictor, const pPlayer, const Vector3( vecOrigin ), const bool: bImpact )
{
	rh_emit_sound2( bImpact ? pPlayer : pInflictor, 0, CHAN_WEAPON, WeaponSounds[ bImpact ] );

	if ( !bImpact )
		UTIL_TE_WORLDDECAL( MSG_BROADCAST, vecOrigin, gl_iDecalIndex_Scorch1 );

	UTIL_TE_EXPLOSION( MSG_PAS, gl_iszModelIndex[ bImpact ? ModelIndex_ExplodeImpact : ModelIndex_ExplodeBomb ], vecOrigin, Float: WeaponExplodeSpriteSettings[ bImpact ][ Sprite_ZOffset ], WeaponExplodeSpriteSettings[ bImpact ][ Sprite_Scale ], WeaponExplodeSpriteSettings[ bImpact ][ Sprite_Framerate ] );

	for ( new pVictim = 1, Vector3( vecVictimOrigin ), Float: flDistance; pVictim <= MaxClients; pVictim++ )
	{
		if ( pVictim == pPlayer )
			continue;

		if ( !is_user_alive( pVictim ) || !zp_get_user_zombie( pVictim ) )
			continue;

		get_entvar( pVictim, var_origin, vecVictimOrigin );
		flDistance = xs_vec_distance( vecOrigin, vecVictimOrigin );

		if ( flDistance > WeaponExplodeRadius[ bImpact ] )
			continue;

		if ( get_entvar( pVictim, var_takedamage ) == DAMAGE_NO )
			continue;

		set_member( pVictim, m_LastHitGroup, HIT_GENERIC );

		ExecuteHamB( Ham_TakeDamage, pVictim, pInflictor, pPlayer, AdjustDamage( WeaponExplodeDamage[ bImpact ], floatclamp( flDistance / WeaponExplodeRadius[ bImpact ], 0.1, 0.99 ) ), WeaponExplodeDamageType );
		UTIL_PlayerKnockBack( pVictim, pPlayer, WeaponExplodeKnockBack[ bImpact ] );
	}
}

public CGrenade__UpdateProperties( const pGrenade )
{
#if defined GrenadeHasGlowEffect
	UTIL_SetEntityRendering( pGrenade, kRenderFxGlowShell, GlowEffectColor, kRenderNormal, GlowEffectThickness );
#else
	// Remove glow effect from ZP
	UTIL_SetEntityRendering( pGrenade );
#endif

	// Remove beam from ZP
	UTIL_TE_KILLBEAM( MSG_BROADCAST, pGrenade );

#if defined GrenadeHasTrailEffect
	UTIL_TE_BEAMFOLLOW( MSG_BROADCAST, pGrenade, gl_iszModelIndex[ ModelIndex_BeamFollow ], TrailEffectLife, TrailEffectWidth, TrailEffectColor, TrailEffectBrightness );
#endif

	set_entvar( pGrenade, var_impulse, WeaponUnicalIndex );
	set_entvar( pGrenade, var_flTimeStepSound, WeaponUnicalIndex ); // Remove grenade physics from ZP
	set_entvar( pGrenade, var_nextthink, get_gametime( ) + 5.0 );
	set_entvar( pGrenade, var_avelocity, Float: { 0.0, 350.0, 0.0 } ); // Rotate by verticale (w/o create new grenade entity)
	set_entvar( pGrenade, var_angles, NULL_VECTOR ); // Ignore src angles
	set_entvar( pGrenade, var_body, WeaponModelWorldBody );

	engfunc( EngFunc_SetModel, pGrenade, WeaponModelWorld );
}

public CEffect__SpawnEntity( const pPlayer )
{
	new pEntity = rg_create_entity( EntityEffectReference );
	if ( is_nullent( pEntity ) )
		return NULLENT;

	new Vector3( vecOrigin ); UTIL_GetEyePosition( pPlayer, vecOrigin );
	new Vector3( vecViewAngle ); get_entvar( pPlayer, var_v_angle, vecViewAngle );

	vecViewAngle[ 0 ] *= -1.0;

	engfunc( EngFunc_SetModel, pEntity, EntityEffectModel );
	engfunc( EngFunc_SetSize, pEntity, Float: { -100.0, -100.0, -100.0 }, Float: { 100.0, 100.0, 100.0 } );
	engfunc( EngFunc_SetOrigin, pEntity, vecOrigin );

	set_entvar( pEntity, var_classname, EntityEffectClassName );
	set_entvar( pEntity, var_impulse, WeaponUnicalIndex ); // Only for check entity simply in non-reapi version
	set_entvar( pEntity, var_skin, 0 );
	set_entvar( pEntity, var_nextthink, get_gametime( ) + EntityEffectNextThink );
	set_entvar( pEntity, var_angles, vecViewAngle );

	set_entvar( pEntity, var_rendermode, kRenderTransAdd );
	set_entvar( pEntity, var_renderamt, 255.0 );

#if defined _reapi_included
	SetThink( pEntity, "CEffect__Think" );
#endif

	UTIL_SetEntityAnim( pEntity );

	return pEntity;
}

public CEffect__Think( const pEntity )
{
#if !defined _reapi_included
	if ( is_nullent( pEntity ) || !IsCustomWeapon( pEntity, WeaponUnicalIndex ) )
		return;
#endif

	static Float: flGameTime; flGameTime = get_gametime( );
	set_entvar( pEntity, var_nextthink, flGameTime + EntityEffectNextThink );

	static iSkin; iSkin = get_entvar( pEntity, var_skin );
	if ( ++iSkin && iSkin >= EntityEffectMaxSkins )
	{
		UTIL_KillEntity( pEntity );
		return;
	}

	set_entvar( pEntity, var_skin, iSkin );
}

/* ~ [ Stocks ] ~ */
/* -> Weapon Animation <- */
stock UTIL_SendWeaponAnim( const iDest, const pReceiver, const iAnim ) 
{
	set_entvar( pReceiver, var_weaponanim, iAnim );

	message_begin( iDest, SVC_WEAPONANIM, .player = pReceiver );
	write_byte( iAnim );
	write_byte( 0 );
	message_end( );
}

#if defined PrecacheSoundsFromModel
	/* -> Automaticly precache Sounds from Model <- */
	/**
	 * This stock is not needed if you use ReHLDS
	 * with this console command 'sv_auto_precache_sounds_in_models 1'
	 **/
	stock UTIL_PrecacheSoundsFromModel( const szModelPath[ ] )
	{
		new pFile;
		if ( !( pFile = fopen( szModelPath, "rt" ) ) )
			return;
		
		new szSoundPath[ 64 ];
		new iNumSeq, iSeqIndex;
		new iEvent, iNumEvents, iEventIndex;
		
		fseek( pFile, 164, SEEK_SET );
		fread( pFile, iNumSeq, BLOCK_INT );
		fread( pFile, iSeqIndex, BLOCK_INT );
		
		for ( new i = 0; i < iNumSeq; i++ )
		{
			fseek( pFile, iSeqIndex + 48 + 176 * i, SEEK_SET );
			fread( pFile, iNumEvents, BLOCK_INT );
			fread( pFile, iEventIndex, BLOCK_INT );
			fseek( pFile, iEventIndex + 176 * i, SEEK_SET );
			
			for ( new k = 0; k < iNumEvents; k++ )
			{
				fseek( pFile, iEventIndex + 4 + 76 * k, SEEK_SET );
				fread( pFile, iEvent, BLOCK_INT );
				fseek( pFile, 4, SEEK_CUR );
				
				if ( iEvent != 5004 )
					continue;
				
				fread_blocks( pFile, szSoundPath, 64, BLOCK_CHAR );
				
				if ( strlen( szSoundPath ) )
				{
					strtolower( szSoundPath );
				#if AMXX_VERSION_NUM < 190
					format( szSoundPath, charsmax( szSoundPath ), "sound/%s", szSoundPath );
					precache_generic_ex( szSoundPath );
				#else
					precache_generic_ex( fmt( "sound/%s", szSoundPath ) );
				#endif
				}
			}
		}
		
		fclose( pFile );
	}
#endif

#if defined WeaponListDir
	/* -> Automaticly precache WeaponList <- */
	stock UTIL_PrecacheWeaponList( const szWeaponList[ ] )
	{
		new szBuffer[ 128 ], pFile;

		format( szBuffer, charsmax( szBuffer ), "sprites/%s.txt", szWeaponList );
		precache_generic_ex( szBuffer );

		if ( !( pFile = fopen( szBuffer, "rb" ) ) )
			return;

		new szSprName[ 64 ], iPos;
		while ( !feof( pFile ) ) 
		{
			fgets( pFile, szBuffer, charsmax( szBuffer ) );
			trim( szBuffer );

			if ( !strlen( szBuffer ) ) 
				continue;

			if ( ( iPos = containi( szBuffer, "640" ) ) == -1 )
				continue;
					
			format( szBuffer, charsmax( szBuffer ), "%s", szBuffer[ iPos + 3 ] );		
			trim( szBuffer );

			strtok( szBuffer, szSprName, charsmax( szSprName ), szBuffer, charsmax( szBuffer ), ' ', 1 );
			trim( szSprName );

		#if AMXX_VERSION_NUM < 190
			formatex( szBuffer, charsmax( szBuffer ), "sprites/%s.spr", szSprName );
			precache_generic_ex( szBuffer );
		#else
			precache_generic_ex( fmt( "sprites/%s.spr", szSprName ) );
		#endif
		}

		fclose( pFile );
	}

	/* -> Weapon List <- */
	#if defined _reapi_included
		stock UTIL_WeaponList( const iDest, const pReceiver, const pItem, szWeaponName[ MAX_NAME_LENGTH ] = "", const iPrimaryAmmoType = -2, iMaxPrimaryAmmo = -2, iSecondaryAmmoType = -2, iMaxSecondaryAmmo = -2, iSlot = -2, iPosition = -2, iWeaponId = -2, iFlags = -2 ) 
		{
			if ( szWeaponName[ 0 ] == EOS )
				rg_get_iteminfo( pItem, ItemInfo_pszName, szWeaponName, charsmax( szWeaponName ) )

			static iMsgId_Weaponlist; if ( !iMsgId_Weaponlist ) iMsgId_Weaponlist = get_user_msgid( "WeaponList" );

			message_begin( iDest, iMsgId_Weaponlist, .player = pReceiver );
			write_string( szWeaponName );
			write_byte( ( iPrimaryAmmoType <= -2 ) ? GetWeaponAmmoType( pItem ) : iPrimaryAmmoType );
			write_byte( ( iMaxPrimaryAmmo <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iMaxAmmo1 ) : iMaxPrimaryAmmo );
			write_byte( ( iSecondaryAmmoType <= -2 ) ? get_member( pItem, m_Weapon_iSecondaryAmmoType ) : iSecondaryAmmoType );
			write_byte( ( iMaxSecondaryAmmo <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iMaxAmmo2 ) : iMaxSecondaryAmmo );
			write_byte( ( iSlot <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iSlot ) : iSlot );
			write_byte( ( iPosition <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iPosition ) : iPosition );
			write_byte( ( iWeaponId <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iId ) : iWeaponId );
			write_byte( ( iFlags <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iFlags ) : iFlags );
			message_end( );
		}
	#else
		/* -> Weapon List <- */
		stock UTIL_WeaponList( const iDist, const pReceiver, const szWeaponName[ ], const iPrimaryAmmoType = -2, iMaxPrimaryAmmo = -2, iSecondaryAmmoType = -2, iMaxSecondaryAmmo = -2, iSlot = -2, iPosition = -2, iWeaponId = -2, iFlags = -2 )
		{
			static iMsgId_Weaponlist; if ( !iMsgId_Weaponlist ) iMsgId_Weaponlist = get_user_msgid( "WeaponList" );
			
			message_begin( iDist, iMsgId_Weaponlist, .player = pReceiver );
			write_string( szWeaponName );
			write_byte( ( iPrimaryAmmoType <= -2 ) ? gl_aWeaponListData[ 0 ] : iPrimaryAmmoType );
			write_byte( ( iMaxPrimaryAmmo <= -2 ) ? gl_aWeaponListData[ 1 ] : iMaxPrimaryAmmo );
			write_byte( ( iSecondaryAmmoType <= -2 ) ? gl_aWeaponListData[ 2 ] : iSecondaryAmmoType );
			write_byte( ( iMaxSecondaryAmmo <= -2 ) ? gl_aWeaponListData[ 3 ] : iMaxSecondaryAmmo );
			write_byte( ( iSlot <= -2 ) ? gl_aWeaponListData[ 4 ] : iSlot );
			write_byte( ( iPosition <= -2 ) ? gl_aWeaponListData[ 5 ] : iPosition );
			write_byte( ( iWeaponId <= -2 ) ? gl_aWeaponListData[ 6 ] : iWeaponId );
			write_byte( ( iFlags <= -2 ) ? gl_aWeaponListData[ 7 ] : iFlags );
			message_end( );
		}
	#endif
#endif

/* -> Destroy Entity <- */
stock UTIL_KillEntity( const pEntity )
{
	set_entvar( pEntity, var_flags, FL_KILLME );
	set_entvar( pEntity, var_nextthink, get_gametime( ) );
}

/* -> Get player eye position <- */
stock UTIL_GetEyePosition( const pPlayer, Vector3( vecEyeLevel ) )
{
	new Vector3( vecOrigin ); get_entvar( pPlayer, var_origin, vecOrigin );
	new Vector3( vecViewOfs ); get_entvar( pPlayer, var_view_ofs, vecViewOfs );

	xs_vec_add( vecOrigin, vecViewOfs, vecEyeLevel );
}

/* -> Get Player vector Aiming <- */
stock UTIL_GetVectorAiming( const pPlayer, Vector3( vecAiming ) ) 
{
	new Vector3( vecViewAngle ); get_entvar( pPlayer, var_v_angle, vecViewAngle );
	new Vector3( vecPunchAngle ); get_entvar( pPlayer, var_punchangle, vecPunchAngle );

	xs_vec_add( vecViewAngle, vecPunchAngle, vecViewAngle );
	angle_vector( vecViewAngle, ANGLEVECTOR_FORWARD, vecAiming );
}

/* -> Strip weapon from player by index <- */
stock bool: UTIL_StripWeaponByIndex( const pPlayer, const pItem )
{
	if ( is_nullent( pItem ) )
		return false;

	if ( get_member( pPlayer, m_pActiveItem ) == pItem )
		ExecuteHamB( Ham_Weapon_RetireWeapon, pItem );

	if ( !ExecuteHamB( Ham_RemovePlayerItem, pPlayer, pItem ) )
		return false;

	ExecuteHamB( Ham_Item_Kill, pItem );
	set_entvar( pPlayer, var_weapons, get_entvar( pPlayer, var_weapons ) & ~( 1<<( get_member( pItem, m_iId ) ) ) );

	return true;
}

#if defined _reapi_included
	/* -> Find item by ClassName <- */
	stock UTIL_GetItemByName( const pPlayer, const szItemName[ ] )
	{
		for ( new i, pItem = NULLENT; i < MAX_ITEM_TYPES; i++ )
		{
			pItem = get_member( pPlayer, m_rgpPlayerItems, i );
			while ( !is_nullent( pItem ) )
			{
				if ( FClassnameIs( pItem, szItemName ) )
					return pItem;

				pItem = get_member( pItem, m_pNext );
			}
		}
		return NULLENT;
	}
#endif

/* -> Set Entity Rendering <- */
stock UTIL_SetEntityRendering( const pEntity, const iRenderFx = kRenderFxNone, const Float: flRenderColor[ 3 ] = { 255.0, 255.0, 255.0 }, const iRenderMode = kRenderNormal, const Float: flRenderAmount = 16.0 )
{
	set_entvar( pEntity, var_renderfx, iRenderFx );
	set_entvar( pEntity, var_rendercolor, flRenderColor );
	set_entvar( pEntity, var_rendermode, iRenderMode );
	set_entvar( pEntity, var_renderamt, flRenderAmount );
}

/* -> Entity Animation <- */
stock UTIL_SetEntityAnim( const pEntity, const iSequence = 0, const Float: flFrame = 0.0, const Float: flFrameRate = 1.0 )
{
	set_entvar( pEntity, var_frame, flFrame );
	set_entvar( pEntity, var_framerate, flFrameRate );
	set_entvar( pEntity, var_animtime, get_gametime( ) );
	set_entvar( pEntity, var_sequence, iSequence );
}

#if !defined _reapi_included
	/* -> Player Animation <- */
	stock UTIL_PlayerAnimation( const pPlayer, const szAnim[ ] ) 
	{
		new iAnimDesired, Float: flFrameRate, Float: flGroundSpeed, bool: bLoops;
		if ( ( iAnimDesired = lookup_sequence( pPlayer, szAnim, flFrameRate, bLoops, flGroundSpeed ) ) == -1 ) 
			iAnimDesired = 0;

		new Float: flGameTime = get_gametime( );

		UTIL_SetEntityAnim( pPlayer, iAnimDesired );

		set_member( pPlayer, m_fSequenceLoops, bLoops );
		set_member( pPlayer, m_fSequenceFinished, 0 );
		set_member( pPlayer, m_flFrameRate, flFrameRate );
		set_member( pPlayer, m_flGroundSpeed, flGroundSpeed );
		set_member( pPlayer, m_flLastEventCheck, flGameTime );
		set_member( pPlayer, m_Activity, ACT_RANGE_ATTACK1 );
		set_member( pPlayer, m_IdealActivity, ACT_RANGE_ATTACK1 );
		set_member( pPlayer, m_flLastFired, flGameTime );
	}
#endif

/* -> Player KnockBack <- */
stock UTIL_PlayerKnockBack( const pVictim, const pAttacker, const Float: flForce, const Float: flVelocityModifier = 0.0 )
{
	if ( flForce == 0.0 )
		return;

	new Vector3( vecOrigin ); get_entvar( pVictim, var_origin, vecOrigin );
	new Vector3( vecVelocity ); get_entvar( pVictim, var_velocity, vecVelocity );
	new Vector3( vecAttackerOrigin ); get_entvar( pAttacker, var_origin, vecAttackerOrigin );
	new Vector3( vecDirection ); xs_vec_sub( vecOrigin, vecAttackerOrigin, vecDirection );
	new Float: flLen = xs_vec_len_2d( vecDirection );

	for ( new i = 0; i < 2; ++i )
		vecVelocity[ i ] = ( vecDirection[ i ] / flLen ) * flForce;

	set_entvar( pVictim, var_velocity, vecVelocity );

	if ( flVelocityModifier )
		set_member( pVictim, m_flVelocityModifier, flVelocityModifier );
}

/* -> TE_KILLBEAM <- */
stock UTIL_TE_KILLBEAM( const iDest, const pEntity )
{
	message_begin( iDest, SVC_TEMPENTITY );
	write_byte( TE_KILLBEAM ); 
	write_short( pEntity );
	message_end( );
}

/* -> TE_BEAMFOLLOW <- */
stock UTIL_TE_BEAMFOLLOW( const iDest, const pEntity, const iszModelIndex, const iLife, const iWidth, const iColor[ 3 ], const iBrightness )
{
	message_begin_f( iDest, SVC_TEMPENTITY );
	write_byte( TE_BEAMFOLLOW );
	write_short( pEntity ); // Entity: attachment to follow
	write_short( iszModelIndex ); // Model Index
	write_byte( iLife ); // Life in 0.1's
	write_byte( iWidth ); // Line width in 0.1's
	write_byte( iColor[ 0 ] ); // Red
	write_byte( iColor[ 1 ] ); // Green
	write_byte( iColor[ 2 ] ); // Blue
	write_byte( iBrightness ); // Brightness
	message_end( );
}

/* -> TE_EXPLOSION <- */
stock UTIL_TE_EXPLOSION( const iDest, const iszModelIndex, const Vector3( vecOrigin ), const Float: flUp, const iScale, const iFramerate, const bitsFlags = TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NOPARTICLES )
{
	message_begin_f( iDest, SVC_TEMPENTITY, vecOrigin );
	write_byte( TE_EXPLOSION );
	write_coord_f( vecOrigin[ 0 ] );
	write_coord_f( vecOrigin[ 1 ] );
	write_coord_f( vecOrigin[ 2 ] + flUp );
	write_short( iszModelIndex );
	write_byte( iScale ); // Scale
	write_byte( iFramerate ); // Framerate
	write_byte( bitsFlags ); // Flags
	message_end( );
}

/* -> TE_WORLDDECAL <- */
stock UTIL_TE_WORLDDECAL( const iDest, const Vector3( vecOrigin ), const iDecalIndex )
{
	message_begin_f( iDest, SVC_TEMPENTITY, vecOrigin );
	write_byte( TE_WORLDDECAL );
	write_coord_f( vecOrigin[ 0 ] );
	write_coord_f( vecOrigin[ 1 ] );
	write_coord_f( vecOrigin[ 2 ] );
	write_byte( iDecalIndex ); // ModelIndex
	message_end( );
}

// by Nordic Warrior
stock precache_model_ex( const szFileName[ ] )
{
	if ( IsNullString( szFileName ) )
		return 0;

	if ( file_exists( szFileName ) )
		return engfunc( EngFunc_PrecacheModel, szFileName );

#if AMXX_VERSION_NUM <= 182
	new szError[ 128 ]; formatex( szError, charsmax( szError ), "Model <%s> not found. The plugin has been stopped.", szFileName );
	set_fail_state( szError );
#else
	set_fail_state( "Model <%s> not found. The plugin has been stopped.", szFileName );
#endif

	return 0;
}

stock precache_sound_ex( const szFileName[ ], const bool: bStopPlugin = false )
{
	if ( IsNullString( szFileName ) )
		return 0;

#if AMXX_VERSION_NUM <= 182
	new szTempBuffer[ 64 ]; format( szTempBuffer, charsmax( szTempBuffer ), "sound/%s", szFileName );
	if ( file_exists( szTempBuffer ) )
#else
	if ( file_exists( fmt( "sound/%s", szFileName ) ) )
#endif
		return engfunc( EngFunc_PrecacheSound, szFileName );

	if ( bStopPlugin )
	{
	#if AMXX_VERSION_NUM <= 182
		new szError[ 128 ]; formatex( szError, charsmax( szError ), "Sound <%s> not found. The plugin has been stopped.", szFileName );
		set_fail_state( szError );
	#else
		set_fail_state( "Sound <%s> not found. The plugin has been stopped.", szFileName );
	#endif
	}
	else
		log_amx( "Sound <%s> not found.", szFileName );

	return 0;
}

stock precache_generic_ex( const szFileName[ ], const bool: bStopPlugin = false )
{
	if ( IsNullString( szFileName ) )
		return 0;

	if ( file_exists( szFileName ) )
		return engfunc( EngFunc_PrecacheGeneric, szFileName );

	if ( bStopPlugin )
	{
	#if AMXX_VERSION_NUM <= 182
		new szError[ 128 ]; formatex( szError, charsmax( szError ), "Generic file <%s> not found. The plugin has been stopped.", szFileName );
		set_fail_state( szError );
	#else
		set_fail_state( "Generic file <%s> not found. The plugin has been stopped.", szFileName );
	#endif
	}
	else
		log_amx( "Generic file <%s> not found.", szFileName );

	return 0;
}
