/* Sublime AMXX-Editor v4.4 */

#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN  "[BOSS] Jungle Abomination"
#define VERSION "1.0.0-376"
#define AUTHOR  "complexcore"

#define BOSS_NAME "jungleabomination"
#define VINE_NAME "abominationvine"

#define var_nextstate var_iuser1
#define var_targetID var_iuser2
#define var_targettime var_fuser1
#define var_attackdelay var_fuser2
#define var_walksoundDelay var_fuser3
#define var_npcspeedmultiplierTime var_fuser4

new g_JungleModelIndex, g_JungleVineIndex, g_mdlCinder, g_bloodSpray, g_bloodDrop, g_smokeSpr;
new g_EntityId = -1;
new Float:_SpeedMultiplier;

new Float:var_npcspeed,
	Float:var_npchealth,
	Float:var_npcdamagemultipler,
	Float:var_npcbasicattackDamage,
	Float:var_npcbasicattackRadius,
	Float:var_npcvineattackDamage

new HamHook:HookTakeDamage;
new HamHook:HookTraceAttack;
new HookChain:HookRoundEnd;

enum (+=100)
{
	TASK_ATTACK = 1781,
	TASK_BREAKMODEL
}

enum _:JUNGLEABOMINATION
{
	JUNGLE_IDLE = 0,
	JUNGLE_WALK,
	JUNGLE_DEATH,
	JUNGLE_FALL,
	JUNGLE_LAND,
	JUNGLE_SUMMON,
	JUNGLE_ATTACK,
	JUNGLE_PROJECTATTACK,
	JUNGLE_VINEATTACK,
	JUNGLE_VINEATTACKLOOP,
	JUNGLE_VINEATTACKEND,
	JUNGLE_REMOVE
}

new const SOUNDS[][] = {
	"jungleabomination/walk2.wav", // 0
	"jungleabomination/walk3.wav", // 1

	"jungleabomination/hit1.wav", // 2
	"jungleabomination/hit2.wav", // 3
	"jungleabomination/hit3.wav", // 4

	"jungleabomination/death.wav", // 5
	"jungleabomination/fall.wav", // 6
	"jungleabomination/land.wav", // 7
	"jungleabomination/basicattack.wav" // 8
};

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	HookTakeDamage = RegisterHam(Ham_TakeDamage, "info_target", "TakeDamage", .Post = false);
	DisableHamForward(HookTakeDamage);
	HookTraceAttack = RegisterHam(Ham_TraceAttack, "info_target", "TraceAttack", .Post = false);
	DisableHamForward(HookTraceAttack);
	HookRoundEnd = RegisterHookChain(RG_RoundEnd, "RoundEnd", false)
	DisableHookChain(HookRoundEnd)

	bind_pcvar_float(create_cvar("jungle_speed", "140.0", ADMIN_RCON, "Boss Hizi", true, 100.0), var_npcspeed);
	bind_pcvar_float(create_cvar("jungle_health", "10000.0", ADMIN_RCON, "Boss Can", true, 5000.0), var_npchealth);
	bind_pcvar_float(create_cvar("jungle_damagemultipler", "1.0", ADMIN_RCON, "Bossun hasar carpani", true, 0.03), var_npcdamagemultipler);
	bind_pcvar_float(create_cvar("jungle_basicattackDamage", "100.0", ADMIN_RCON, "Bossun normal hasari", true, 50.0), var_npcbasicattackDamage);
	bind_pcvar_float(create_cvar("jungle_basicattackRadius", "300.0", ADMIN_RCON, "Bossun normal hasari", true, 250.0), var_npcbasicattackRadius);
	bind_pcvar_float(create_cvar("jungle_vineattackDamage", "25.0", ADMIN_RCON, "Bossun sarmasik hasari", true, 25.0), var_npcvineattackDamage);

	register_clcmd("radio1", "_noclip");
	register_clcmd("radio2", "createJungle");
}

public _noclip(player){
	set_entvar(player, var_movetype, get_entvar(player, var_movetype) == MOVETYPE_NOCLIP ? MOVETYPE_WALK : MOVETYPE_NOCLIP);
	return HC_SUPERCEDE;
}

public plugin_precache() {
	g_JungleModelIndex = precache_model("models/jungleabomination/jungleabomination.mdl");
	g_JungleVineIndex = precache_model("models/jungleabomination/abominationvine.mdl");
	g_mdlCinder = precache_model("models/cindergibs.mdl");
	g_bloodSpray = precache_model("sprites/bloodspray.spr");
	g_bloodDrop  = precache_model("sprites/blood.spr");
	g_smokeSpr = precache_model("sprites/steam1.spr");
	for (new i = 0; i < sizeof SOUNDS; i++)
	{
		precache_sound(SOUNDS[i]);
	}
}

public createJungle(const clientIndex)
{
	if(g_EntityId != -1) rg_remove_entity(g_EntityId);

	g_EntityId = rg_create_entity("info_target");

	if(is_nullent(g_EntityId)){
		client_print_color(0, print_team_red, "^3[^4JUNGLE^3] ^1Nullent");
		return PLUGIN_HANDLED;
	}

	set_entvar(g_EntityId, var_globalname, BOSS_NAME);

	new Float:origin[3];
	get_entvar(clientIndex, var_origin, origin);

	origin[2] += 200.0; 
	set_entvar(g_EntityId, var_origin, origin);

	set_entvar(g_EntityId, var_modelindex, g_JungleModelIndex);
	set_entvar(g_EntityId, var_movetype, MOVETYPE_PUSHSTEP);
	set_entvar(g_EntityId, var_solid, SOLID_BBOX);

	new Float:mins[3] = { -10.0, -100.0, -1.0 };
	new Float:maxs[3] = { 50.0, 100.0, 300.0 };
	set_entvar(g_EntityId, var_mins, mins);
	set_entvar(g_EntityId, var_maxs, maxs);
	new Float:size[3];
	size[0] = maxs[0] - mins[0]; // 32.0
	size[1] = maxs[1] - mins[1]; // 32.0
	size[2] = maxs[2] - mins[2]; // 72.0
	set_entvar(g_EntityId, var_size, size);

	set_entvar(g_EntityId, var_takedamage, DAMAGE_YES);
	set_entvar(g_EntityId, var_health, var_npchealth);
	set_entvar(g_EntityId, var_max_health, var_npchealth);
	set_entvar(g_EntityId, var_flags, FL_MONSTER);
	set_entvar(g_EntityId, var_deadflag, DEAD_NO);
	set_entvar(g_EntityId, var_sequence, JUNGLE_FALL);
	set_entvar(g_EntityId, var_nextstate, JUNGLE_LAND)

	set_entvar(g_EntityId, var_targetID, -1);
	set_entvar(g_EntityId, var_targettime, get_gametime());
	_SpeedMultiplier = 1.0;
	set_entvar(g_EntityId, var_npcspeedmultiplierTime, get_gametime() + 12.0);
	set_entvar(g_EntityId, var_attackdelay, get_gametime());

	set_entvar(g_EntityId, var_framerate, 1.00);
	set_entvar(g_EntityId, var_animtime, get_gametime());

	EnableHamForward(HookTakeDamage);
	EnableHamForward(HookTraceAttack);
	EnableHookChain(HookRoundEnd);

	SetThink(g_EntityId, "Think_JungleCallBack");
	set_entvar(g_EntityId, var_nextthink, get_gametime() + 0.86);
	if(is_rehlds())
	{
		rh_emit_sound2(g_EntityId, 0, CHAN_STATIC, SOUNDS[6], VOL_NORM, ATTN_NORM, _, random_num(PITCH_LOW, PITCH_HIGH))
	}
	else
	{
		emit_sound(g_EntityId, CHAN_STATIC, SOUNDS[6], VOL_NORM, ATTN_NORM, 0, random_num(PITCH_LOW, PITCH_HIGH));
	}
	return HC_SUPERCEDE
}

public Think_JungleCallBack(const ent) {
	if(!is_entity(ent) || get_entvar(ent, var_deadflag) == DEAD_DEAD) {
		SetThink(ent, "")
		set_entvar(ent, var_flags, FL_KILLME);
		if(!is_nullent(ent)) rg_remove_entity(ent);
		g_EntityId = -1;
		return HC_SUPERCEDE;
	}

	if(Float:get_entvar(ent, var_targettime) < get_gametime())
	{
		set_entvar(ent, var_targetID, find_closest_player(ent));
		set_entvar(ent, var_targettime, get_gametime() + 10.0)
	}
	
	static target = -1; 
	target = get_entvar(ent, var_targetID)

	if(!is_user_alive(target) || !is_user_connected(target))
	{
		set_entvar(ent, var_targettime, get_gametime())
		set_entvar(ent, var_nextthink, get_gametime() + 0.1)
		return HC_SUPERCEDE
	}

	static Float:nextThink = 0.1;
	static _state = -1;
	_state = get_entvar(ent, var_nextstate);
	static newState = JUNGLE_IDLE;
	static newAnim = JUNGLE_IDLE;

	switch(_state)
	{
		case JUNGLE_REMOVE:
		{
			set_entvar(ent, var_deadflag, DEAD_DEAD);
			newAnim = JUNGLE_DEATH
			nextThink = 3.0
		}
		case JUNGLE_DEATH:
		{
			set_entvar(ent, var_takedamage, DAMAGE_NO);
			nextThink = 2.33;
			DisableHamForward(HookTakeDamage);
			DisableHamForward(HookTraceAttack);
			DisableHookChain(HookRoundEnd);
			newAnim = JUNGLE_DEATH
			newState = JUNGLE_REMOVE;
			if(is_rehlds())
			{
				rh_emit_sound2(ent, 0, CHAN_STATIC, SOUNDS[5], VOL_NORM, ATTN_NORM, _, random_num(PITCH_LOW, PITCH_HIGH))
			}
			else
			{
				emit_sound(ent, CHAN_STATIC, SOUNDS[5], VOL_NORM, ATTN_NORM, 0, random_num(PITCH_LOW, PITCH_HIGH));
			}
		}
		case JUNGLE_IDLE:
		{
			nextThink = 5.97;
			newAnim = JUNGLE_IDLE
			newState = JUNGLE_IDLE;
		}
		case JUNGLE_LAND:
		{
			nextThink = 2.40;
			newAnim = JUNGLE_LAND
			newState = JUNGLE_WALK;
			set_entvar(ent, var_targettime, get_gametime())

			if(is_rehlds())
			{
				rh_emit_sound2(ent, 0, CHAN_STATIC, SOUNDS[7], VOL_NORM, ATTN_NORM, _, random_num(PITCH_LOW, PITCH_HIGH))
			}
			else
			{
				emit_sound(ent, CHAN_STATIC, SOUNDS[7], VOL_NORM, ATTN_NORM, 0, random_num(PITCH_LOW, PITCH_HIGH));
			}
		}
		case JUNGLE_WALK:
		{
			TurnToTarget(ent, target);
			newAnim = JUNGLE_WALK

			if(Float:get_entvar(ent, var_walksoundDelay) < get_gametime())
			{
				if(is_rehlds())
				{
					rh_emit_sound2(ent, 0, CHAN_STATIC, SOUNDS[random_num(0, 1)], VOL_NORM, ATTN_NORM, _, random_num(PITCH_LOW, PITCH_HIGH))
				}
				else
				{
					emit_sound(ent, CHAN_STATIC, SOUNDS[random_num(0, 1)], VOL_NORM, ATTN_NORM, 0, random_num(PITCH_LOW, PITCH_HIGH));
				}
				set_entvar(ent, var_walksoundDelay, get_gametime() + 1.0);
			}

			if(Float:get_entvar(ent, var_npcspeedmultiplierTime) < get_gametime())
			{
				_SpeedMultiplier += 0.2;
				set_entvar(ent, var_npcspeedmultiplierTime, get_gametime() + nextThink + 4.0);
			}

			if(!find_player_distance(ent, target, 300.0))
			{
				MoveSmartToTarget(ent, target);
			}
			else if(Float:get_entvar(ent, var_attackdelay) < get_gametime())
			{
				newState = random_num(1, 100) >= 85 ? JUNGLE_VINEATTACK : JUNGLE_ATTACK;
			}
			else
			{
				newState = JUNGLE_WALK;
			}

			nextThink = 0.1
		}
		case JUNGLE_ATTACK:
		{
			_SpeedMultiplier = 1.0
			nextThink = 2.0;
			newAnim = JUNGLE_ATTACK
			newState = JUNGLE_WALK;
			set_entvar(ent, var_targettime, get_gametime())
			
			set_entvar(ent, var_attackdelay, get_gametime() + 4.0)

			set_entvar(ent, var_npcspeedmultiplierTime, get_gametime() + nextThink + 6.0);

			static Float:origin[3]
			get_entvar(target, var_origin, origin)
			attack_damage(ent, target, 1.0)
			set_task(1.0, "BreakWallEffect", TASK_BREAKMODEL + ent, origin, 3);

			if(is_rehlds())
			{
				rh_emit_sound2(g_EntityId, 0, CHAN_STATIC, SOUNDS[8], VOL_NORM, ATTN_NORM, _, random_num(PITCH_LOW, PITCH_HIGH))
			}
			else
			{
				emit_sound(g_EntityId, CHAN_STATIC, SOUNDS[8], VOL_NORM, ATTN_NORM, 0, random_num(PITCH_LOW, PITCH_HIGH));
			}
		}
		case JUNGLE_VINEATTACK:
		{
			_SpeedMultiplier = 1.0
			nextThink = 1.53;
			newAnim = JUNGLE_VINEATTACK
			newState = JUNGLE_VINEATTACKLOOP;
		}
		case JUNGLE_VINEATTACKLOOP:
		{
			_SpeedMultiplier = 1.0
			nextThink = 3.00;
			newAnim = JUNGLE_VINEATTACKLOOP
			newState = JUNGLE_VINEATTACKEND
			static Float:bossOrigin[3];
			get_entvar(ent, var_origin, bossOrigin);

			static Float:spawnOrigin[3];
			for(new i=0; i <= 20; i++)
			{
				if(GetRandomValidLocation(bossOrigin, 400.0, spawnOrigin))
				{
					createVine(spawnOrigin)

					message_begin_f(MSG_PVS, SVC_TEMPENTITY, spawnOrigin, 0);
					write_byte(TE_EXPLOSION);
					write_coord_f(spawnOrigin[0]);
					write_coord_f(spawnOrigin[1]);
					write_coord_f(spawnOrigin[2] + 30.0); // Biraz yukarıda
					write_short(g_smokeSpr); // steam1.spr
					write_byte(20);  // Scale (Büyüklük - 30 baya büyüktür)
					write_byte(12);  // Framerate
					write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES); 
					message_end();
				}
			}
		}
		case JUNGLE_VINEATTACKEND:
		{
			_SpeedMultiplier = 1.0
			nextThink = 1.50;
			set_entvar(ent, var_targettime, get_gametime())
			newState = JUNGLE_WALK;
			newAnim = JUNGLE_VINEATTACKEND
			set_entvar(ent, var_attackdelay, get_gametime() + 4.0)
		}
	}
	
	if(get_entvar(ent, var_sequence) != newAnim)
	{
		set_entvar(ent, var_sequence, newAnim);
		set_entvar(ent, var_animtime, get_gametime());
	}

	set_entvar(ent, var_nextstate, newState)
	set_entvar(ent, var_nextthink, get_gametime() + nextThink);
	return HC_CONTINUE;
}

public attack_damage(const ent, const enemy, Float:time)
{
	if(!is_entity(ent) || !is_user_alive(enemy) || !is_user_connected(enemy))
		return;
	
	static Float:origin[3];
	get_entvar(enemy, var_origin, origin);

	set_task(time, "_attack_damage", TASK_ATTACK + ent, origin, 3);
}

public _attack_damage(Float:params[], id)
{
	if(!is_entity(g_EntityId))
		return;

	static Float:origin[3];
	origin[0] = params[0];
	origin[1] = params[1];
	origin[2] = params[2];

	rg_dmg_radius(origin, g_EntityId, g_EntityId, var_npcbasicattackDamage, var_npcbasicattackRadius, g_EntityId, DMG_SLASH);
}

public createVine(const Float:origin[3])
{
	new vine = rg_create_entity("info_target");

	if(is_nullent(vine)){
		client_print_color(0, print_team_red, "^3[^4VINE^3] ^1Nullent");
		return PLUGIN_HANDLED;
	}

	set_entvar(vine, var_globalname, VINE_NAME);

	set_entvar(vine, var_origin, origin);

	set_entvar(vine, var_modelindex, g_JungleVineIndex);
	new Float:mins[3] = { -20.0, -20.0, -1.0 };
	new Float:maxs[3] = { 20.0, 20.0, 50.0 };
	set_entvar(vine, var_mins, mins);
	set_entvar(vine, var_maxs, maxs);
	new Float:size[3];
	size[0] = maxs[0] - mins[0]; // 32.0
	size[1] = maxs[1] - mins[1]; // 32.0
	size[2] = maxs[2] - mins[2]; // 72.0
	set_entvar(vine, var_size, size);

	set_entvar(vine, var_movetype, MOVETYPE_FLY);
	set_entvar(vine, var_solid, SOLID_TRIGGER);

	set_entvar(vine, var_flags, FL_MONSTER);
	set_entvar(vine, var_deadflag, DEAD_NO);
	set_entvar(vine, var_sequence, 1);

	set_entvar(vine, var_framerate, 1.00);
	set_entvar(vine, var_animtime, get_gametime());

	SetTouch(vine, "Touch_VineCallBack")
	SetThink(vine, "Think_VineCallBack")
	set_entvar(vine, var_nextthink, get_gametime() + 3.0)
	return HC_SUPERCEDE
}

public Touch_VineCallBack(const ent, const toucher)
{
	if(!is_user_connected(toucher) || !is_user_alive(toucher))
		return HC_CONTINUE

	if(g_EntityId == -1 || !is_entity(ent)) {
		SetTouch(ent, "")
		set_entvar(ent, var_flags, FL_KILLME);
		if(!is_nullent(ent)) rg_remove_entity(ent);
		return HC_SUPERCEDE;
	}
	if(get_entvar(ent, var_fuser1) > get_gametime())
		return HC_CONTINUE;

	rg_multidmg_clear();
	rg_multidmg_add(ent, toucher, var_npcvineattackDamage, DMG_SLASH | DMG_PARALYZE);
	rg_multidmg_apply(ent, g_EntityId);

	static Float:punch[3];
	punch[0] = random_float(-5.0, 5.0);
	punch[1] = random_float(-5.0, 5.0);
	set_entvar(toucher, var_punchangle, punch);
	set_entvar(ent, var_fuser1, get_gametime() + 1.0);
	return HC_CONTINUE
}

public Think_VineCallBack(const ent)
{
	if(g_EntityId == -1 || !is_entity(ent) || get_entvar(ent, var_deadflag) == DEAD_DEAD) {
		SetThink(ent, "")
		set_entvar(ent, var_flags, FL_KILLME);
		if(!is_nullent(ent)) rg_remove_entity(ent);
		return HC_SUPERCEDE;
	}

	set_entvar(ent, var_nextthink, get_gametime() + 2.21);
	set_entvar(ent, var_deadflag, DEAD_DEAD)
	return HC_SUPERCEDE
}

public TakeDamage(victim, idinflictor, idattacker, Float:flDamage, damagebits)
{
	static globalname[64]
	get_entvar(victim, var_globalname, globalname, charsmax(globalname))

	if(!equal(globalname, BOSS_NAME)) return HAM_IGNORED;
	if(get_entvar(victim, var_deadflag) != DEAD_NO) return HAM_SUPERCEDE;
	if(!is_user_connected(idattacker)) return HAM_SUPERCEDE;
	if(victim == idattacker || victim == idinflictor) return HAM_SUPERCEDE;
	if(get_member(idattacker, m_iTeam) != TeamName:TEAM_CT) return HAM_SUPERCEDE;

	static Float:_newflDamage;
	_newflDamage = flDamage * var_npcdamagemultipler;
	
	if(Float:get_entvar(victim, var_health) - _newflDamage <= 1.0)
	{
		set_entvar(victim, var_health, 1.0);
		set_entvar(victim, var_nextstate, JUNGLE_DEATH)
		set_entvar(victim, var_deadflag, DEAD_DYING)
		set_entvar(victim, var_solid, SOLID_NOT)
		set_entvar(victim, var_movetype, MOVETYPE_NONE)
		remove_alltask()
		set_entvar(victim, var_nextthink, get_gametime() + 0.1)
		new name[32]
		get_user_name(idattacker, name, charsmax(name))
		client_print_color(0, print_team_red, "^1[^4BOSS^1] ^3%s ^1Adlı oyuncu ^4BOSS^1'u öldürdü.", name)
		return HAM_SUPERCEDE
	}
	else
	{
		set_entvar(victim, var_health, Float:get_entvar(victim, var_health) - _newflDamage);
		client_print(0, print_center, "Health: %.0f", get_entvar(victim, var_health))
		if(is_rehlds())
		{
			rh_emit_sound2(victim, 0, CHAN_STATIC, SOUNDS[random_num(2, 4)], VOL_NORM, ATTN_NORM, _, random_num(PITCH_LOW, PITCH_HIGH))
		}
		else
		{
			emit_sound(victim, CHAN_STATIC, SOUNDS[random_num(2, 4)], VOL_NORM, ATTN_NORM, 0, random_num(PITCH_LOW, PITCH_HIGH));
		}
		return HAM_SUPERCEDE
	}
}

public TraceAttack(victim, idattacker, Float:damage, Float:direction[3], traceresult, damagebits)
{
	static globalname[64]
	get_entvar(victim, var_globalname, globalname, charsmax(globalname))

	if(!equal(globalname, BOSS_NAME)) return HAM_IGNORED;
	if(get_entvar(victim, var_deadflag) != DEAD_NO) return HAM_SUPERCEDE;
	if(!is_user_connected(idattacker)) return HAM_SUPERCEDE;
	if(victim == idattacker) return HAM_SUPERCEDE;
	if(get_member(idattacker, m_iTeam) != TeamName:TEAM_CT) return HAM_SUPERCEDE;

	static Float:hitPos[3];
	get_tr2(traceresult, TR_vecEndPos, hitPos);

	create_bloodsprite_effect(hitPos);
	return HAM_HANDLED
}

public RoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	if(is_entity(g_EntityId))
	{
		DisableHamForward(HookTakeDamage);
		DisableHamForward(HookTraceAttack);
		remove_alltask()
		rg_remove_entity(g_EntityId)
		g_EntityId = -1
	}
}

public BreakWallEffect(Float:params[], id)
{
	static Float:origin[3];
	origin[0] = params[0];
	origin[1] = params[1];
	origin[2] = params[2];

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BREAKMODEL);
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2]));
	write_coord(64);   // sizeX
	write_coord(64);   // sizeY
	write_coord(32);   // sizeZ
	write_coord(random_num(-200,200)); // velX
	write_coord(random_num(-200,200)); // velY
	write_coord(200);                  // velZ
	write_byte(20);
	write_short(g_mdlCinder);
	write_byte(20);
	write_byte(25);
	write_byte(BREAK_CONCRETE);
	message_end();
}

public plugin_end()
{
	remove_alltask()
	if(is_entity(g_EntityId)) rg_remove_entity(g_EntityId)
}

create_bloodsprite_effect(Float:origin[3])
{
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin, 0);
	write_byte(TE_BLOODSPRITE);
	write_coord_f(origin[0]);
	write_coord_f(origin[1]);
	write_coord_f(origin[2]);
	write_short(g_bloodSpray);
	write_short(g_bloodDrop)
	write_byte(105);
	write_byte(15);
	message_end();
}

remove_alltask()
{
	remove_task(TASK_ATTACK + g_EntityId);
	remove_task(TASK_BREAKMODEL + g_EntityId);

	for(new i = 0; i < sizeof(SOUNDS); i++)
	{
		if(!is_entity(g_EntityId)) break;

		if(is_rehlds())
		{
			rh_emit_sound2(g_EntityId, 0, CHAN_STATIC, SOUNDS[8], VOL_NORM, ATTN_NORM, SND_STOP, random_num(PITCH_LOW, PITCH_HIGH))
		}
		else
		{
			emit_sound(g_EntityId, CHAN_STATIC, SOUNDS[8], VOL_NORM, ATTN_NORM, SND_STOP, random_num(PITCH_LOW, PITCH_HIGH));
		}
	}
}

find_closest_player(const entity) {
	if (!is_entity(entity)) {
		return 0;
	}

	static Float:entity_origin[3];
	get_entvar(entity, var_origin, entity_origin);

	static players[32], num;
	get_players(players, num, "aeh", "CT");

	static closest_player
	closest_player = -1
	static Float:min_distance;
	min_distance = 999999.0;
	static i, player;
	static Float:player_origin[3];
	static Float:distance = 0.0;

	for (i = 0; i < num; i++) {
		player = players[i];

		if(num > 1 && get_entvar(entity, var_targetID) == player){
			continue;
		}

		get_entvar(player, var_origin, player_origin);

		distance = vector_distance(entity_origin, player_origin);

		if (distance < min_distance) {
			min_distance = distance;
			closest_player = player;
		}
	}

	return closest_player;
}

bool:find_player_distance(const entity, const player, Float:fdistance)
{
	if (!is_entity(entity) || !is_user_alive(player)) {
		return false;
	}
	static Float:entity_origin[3];
	get_entvar(entity, var_origin, entity_origin);

	static Float:player_origin[3];
	get_entvar(player, var_origin, player_origin);

	static Float:distance = 0.0
	distance = vector_distance(entity_origin, player_origin);
	if (distance < fdistance){
		return true;
	}

	return false;
}

TurnToTarget(entity, enemy)
{
	if (!is_user_alive(enemy) || !is_user_connected(enemy) || !is_entity(entity))
		return;

	static Float:npcOrigin[3], Float:playerOrigin[3], Float:dir[3], Float:targetAngles[3];
	
	// Konumları al
	get_entvar(entity, var_origin, npcOrigin);
	get_entvar(enemy, var_origin, playerOrigin);

	// Yön vektörünü hesapla (Sadece X ve Y, yani yere paralel)
	dir[0] = playerOrigin[0] - npcOrigin[0];
	dir[1] = playerOrigin[1] - npcOrigin[1];
	dir[2] = 0.0;

	engfunc(EngFunc_VecToAngles, dir, targetAngles);

	set_entvar(entity, var_angles, targetAngles);
}

MoveSmartToTarget(ent, target)
{
	if (!is_entity(ent) || !is_user_alive(target) || !is_user_connected(target))
		return;

	static Float:npcOrigin[3], Float:targetOrigin[3];
	get_entvar(ent, var_origin, npcOrigin);
	get_entvar(target, var_origin, targetOrigin);

	// XY yön vektörü
	static Float:dir[3];
	dir[0] = targetOrigin[0] - npcOrigin[0];
	dir[1] = targetOrigin[1] - npcOrigin[1];
	dir[2] = 0.0;

	static Float:len;
	len = floatsqroot(dir[0]*dir[0] + dir[1]*dir[1]);
	if (len == 0.0) return;

	dir[0] /= len;
	dir[1] /= len;

	static Float:vel[3], Float:speed;
	speed = var_npcspeed * _SpeedMultiplier;
	static Float:angles[3], Float:ret[3];

	if (NPC_CheckForwardObstacle(ent))
	{
		if (!NPC_CheckSideObstacle(ent, true))
		{
			get_entvar(ent, var_angles, angles);
			angle_vector(angles, ANGLEVECTOR_RIGHT, ret);

			vel[0] = ret[0] * speed;
			vel[1] = ret[1] * speed;
			vel[2] = 0.0;
		}
		else if (!NPC_CheckSideObstacle(ent, false))
		{
			get_entvar(ent, var_angles, angles);
			angle_vector(angles, ANGLEVECTOR_RIGHT, ret);

			ret[0] = -ret[0];
			ret[1] = -ret[1];
			ret[2] = -ret[2];

			vel[0] = ret[0] * speed;
			vel[1] = ret[1] * speed;
			vel[2] = 0.0;
		}
		else
		{
			vel[0] = 0.0;
			vel[1] = 0.0;
			vel[2] = 0.0;
		}
	}
	else
	{
	    vel[0] = dir[0] * speed;
	    vel[1] = dir[1] * speed;
	    vel[2] = 0.0;
	}
	
	set_entvar(ent, var_velocity, vel);
}

bool:NPC_CheckForwardObstacle(ent, Float:distance = 125.0)
{
	if (!is_entity(ent))
		return false;

	static Float:origin[3], Float:angles[3], Float:_forward[3];
	get_entvar(ent, var_origin, origin);
	get_entvar(ent, var_angles, angles);

	origin[2] -= 48.0; 

	angle_vector(angles, ANGLEVECTOR_FORWARD, _forward);

	static Float:end[3];
	end[0] = origin[0] + _forward[0] * distance;
	end[1] = origin[1] + _forward[1] * distance;
	end[2] = origin[2] + _forward[2] * distance;

	static trace;
	engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, ent, trace);

	static Float:fraction;
	get_tr2(trace, TR_flFraction, fraction);

	if (fraction < 1.0) 
	{
		return true;
	}
	return false;
}

bool:NPC_CheckSideObstacle(ent, bool:right = true, Float:distance = 125.0)
{
	if (!is_entity(ent))
		return false;

	static Float:origin[3], Float:angles[3], Float:side[3];
	get_entvar(ent, var_origin, origin);
	get_entvar(ent, var_angles, angles);

	origin[2] -= 48.0;

	angle_vector(angles, ANGLEVECTOR_RIGHT, side);
	if (!right)
	{
		side[0] = -side[0];
		side[1] = -side[1];
		side[2] = -side[2];
	}

	// Hedef nokta
	static Float:end[3];
	end[0] = origin[0] + side[0] * distance;
	end[1] = origin[1] + side[1] * distance;
	end[2] = origin[2] + side[2] * distance;

	static trace;
	engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, ent, trace);

	static Float:fraction;
	get_tr2(trace, TR_flFraction, fraction);

	if (fraction < 1.0)
	{
		return true;
	}
	return false;
}

bool:GetRandomValidLocation(const Float:origin[3], Float:radius, Float:validOrigin[3])
{
	static Float:randomOrigin[3];
	static Float:traceStart[3];
	static Float:traceEnd[3];
	static Float:floorOrigin[3];
	static tr;
	static Float:fraction;
	
	// 20 deneme hakkı verelim
	for(new i = 0; i < 10; i++)
	{
		// 1. Rastgele X ve Y
		randomOrigin[0] = origin[0] + random_float(-radius, radius);
		randomOrigin[1] = origin[1] + random_float(-radius, radius);
		
		// 2. Işın Başlangıcı ve Bitişi
		// Başlangıcı Boss'un olduğu hizadan biraz yukarı alalım (kafa hizası)
		traceStart[0] = randomOrigin[0];
		traceStart[1] = randomOrigin[1];
		traceStart[2] = origin[2] + 50.0; 

		// Bitişi aşağısı
		traceEnd[0] = randomOrigin[0];
		traceEnd[1] = randomOrigin[1];
		traceEnd[2] = origin[2] - 1000.0;

		// 3. Zemini Ara (TraceLine)
		engfunc(EngFunc_TraceLine, traceStart, traceEnd, IGNORE_MONSTERS, 0, tr);
		get_tr2(tr, TR_flFraction, fraction);

		// Eğer hiçbir yere çarpmadıysa (Harita boşluğuna denk geldiyse)
		if(fraction >= 1.0) {
			// client_print(0, print_chat, "[DEBUG] Deneme %d: Zemin bulunamadi (Void)", i);
			continue;
		}
		
		// Eğer başlangıç noktası doluysa (Duvarın içinden başladıysa)
		if(get_tr2(tr, TR_StartSolid)) {
			// client_print(0, print_chat, "[DEBUG] Deneme %d: Duvar icinde basladi", i);
			continue;
		}

		// Zemin noktasını al
		get_tr2(tr, TR_vecEndPos, floorOrigin);

		// 4. ALAN KONTROLÜ (GÜNCELLENDİ)
		// Kontrol noktasını zeminden 36 birim yukarı kaldırıyoruz.
		// Neden? Çünkü HULL_HUMAN yaklaşık 72 birimdir. Merkezi 36'dır.
		// Eğer tam zeminde (0) ararsak, kutunun altı yere gömülür ve hata verir.
		static Float:checkOrigin[3];
		checkOrigin = floorOrigin;
		checkOrigin[2] += 36.0; 

		// YÖNTEM A: TraceHull (Daha güvenli ama nazlı)
		engfunc(EngFunc_TraceHull, checkOrigin, checkOrigin, IGNORE_MONSTERS, HULL_HUMAN, 0, tr);
		
		// YÖNTEM B: PointContents (Daha rahat ama duvar içine kaçabilir)
		// Eğer TraceHull çalışmazsa bunu deneyeceğiz.
		// new contents = engfunc(EngFunc_PointContents, checkOrigin);

		if(get_tr2(tr, TR_InOpen) && !get_tr2(tr, TR_AllSolid) && !get_tr2(tr, TR_StartSolid))
		{
			// Başarılı! Zemin koordinatını döndür.
			// Entity'i hafif yukarı koy ki yere yapışmasın
			floorOrigin[2] += 5.0; 
			validOrigin = floorOrigin;
			return true;
		}
	}

	return false;
}