#define LIGHT_DAM_THRESHOLD 4
#define LIGHT_HEAL_THRESHOLD 2
#define LIGHT_DAMAGE_TAKEN 10

/*

SHADOWLING: A gamemode based on previously-run events

Aliens called shadowlings are on the station.
These shadowlings can 'enthrall' crew members and enslave them.
They also burn in the light but heal rapidly whilst in the dark.
The game will end under two conditions:
	1. The shadowlings die
	2. The emergency shuttle docks at CentCom

Shadowling strengths:
	- The dark
	- Hard vacuum (They are not affected by it)
	- Their thralls who are not harmed by the light
	- Stealth

Shadowling weaknesses:
	- The light
	- Fire
	- Enemy numbers
	- Lasers (Lasers are concentrated light and do more damage)
	- Flashbangs (High stun and high burn damage; if the light stuns humans, you bet your ass it'll hurt the shadowling very much!)

Shadowlings start off disguised as normal crew members, and they only have two abilities: Hatch and Enthrall.
They can still enthrall and perhaps complete their objectives in this form.
Hatch will, after a short time, cast off the human disguise and assume the shadowling's true identity.
They will then assume the normal shadowling form and gain their abilities.

The shadowling will seem OP, and that's because it kinda is. Being restricted to the dark while being alone most of the time is extremely difficult and as such the shadowling needs powerful abilities.
Made by Xhuis

*/



/*
	GAMEMODE
*/


/datum/game_mode
	var/list/datum/mind/shadows = list()
	var/list/datum/mind/thralls = list()
	var/list/shadow_objectives = list()
	var/required_thralls = 15 //How many thralls are needed (hardcoded for now)
	var/shadowling_ascended = 0 //If at least one shadowling has ascended
	var/shadowling_dead = 0 //is shadowling kill
	var/objective_explanation


/proc/is_thrall(var/mob/living/M)
	return istype(M) && M.mind && ticker && ticker.mode && (M.mind in ticker.mode.thralls)


/proc/is_shadow_or_thrall(var/mob/living/M)
	return istype(M) && M.mind && ticker && ticker.mode && ((M.mind in ticker.mode.thralls) || (M.mind in ticker.mode.shadows))


/proc/is_shadow(var/mob/living/M)
	return istype(M) && M.mind && ticker && ticker.mode && (M.mind in ticker.mode.shadows)


/datum/game_mode/shadowling
	name = "shadowling"
	config_tag = "shadowling"
	antag_flag = BE_SHADOWLING
	required_players = 30
	required_enemies = 4
	recommended_enemies = 3
	restricted_jobs = list("AI", "Cyborg")
	protected_jobs = list("Security Officer", "Warden", "Detective", "Head of Security", "Captain")

/datum/game_mode/shadowling/announce()
	world << "<b>The current game mode is - Shadowling!</b>"
	world << "<b>There are alien <span class='shadowling'>shadowlings</span> on the station. Crew: Kill the shadowlings before they can eat or enthrall the crew. Shadowlings: Enthrall the crew while remaining in hiding.</b>"

/datum/game_mode/shadowling/pre_setup()
	if(config.protect_roles_from_antagonist)
		restricted_jobs += protected_jobs

	if(config.protect_assistant_from_antagonist)
		restricted_jobs += "Assistant"

	for(var/datum/mind/player in antag_candidates)
		for(var/job in restricted_jobs)
			if(player.assigned_role == job)
				antag_candidates -= player

	var/shadowlings = 2 //How many shadowlings there are; hardcoded to 2

	while(shadowlings)
		var/datum/mind/shadow = pick(antag_candidates)
		shadows += shadow
		antag_candidates -= shadow
		modePlayer += shadow
		shadow.special_role = "Shadowling"
		shadowlings--
	return 1


/datum/game_mode/shadowling/post_setup()
	for(var/datum/mind/shadow in shadows)
		log_game("[shadow.key] (ckey) has been selected as a Shadowling.")
		sleep(10)
		shadow.current << "<br>"
		shadow.current << "<span class='deadsay'><b><font size=3>You are a shadowling!</font></b></span>"
		greet_shadow(shadow)
		finalize_shadowling(shadow)
		process_shadow_objectives(shadow)
		//give_shadowling_abilities(shadow)

	..()
	return

/datum/game_mode/proc/greet_shadow(var/datum/mind/shadow)
	shadow.current << "<b>Currently, you are disguised as an employee aboard [station_name()].</b>"
	shadow.current << "<b>In your limited state, you have three abilities: Enthrall, Hatch, and Hivemind Commune.</b>"
	shadow.current << "<b>Any other shadowlings are your allies. You must assist them as they shall assist you.</b>"
	shadow.current << "<b>If you are new to shadowling, or want to read about abilities, check the wiki page at https://tgstation13.org/wiki/Shadowling</b><br>"


/datum/game_mode/proc/process_shadow_objectives(var/datum/mind/shadow_mind)
	var/objective = "enthrall" //may be devour later, but for now it seems murderbone-y

	if(objective == "enthrall")
		objective_explanation = "Ascend to your true form by use of the Ascendance ability. This may only be used with [required_thralls] collective thralls, while hatched, and is unlocked with the Collective Mind ability."
		shadow_objectives += "enthrall"
		shadow_mind.memory += "<b>Objective #1</b>: [objective_explanation]"
		shadow_mind.current << "<b>Objective #1</b>: [objective_explanation]<br>"


/datum/game_mode/proc/finalize_shadowling(var/datum/mind/shadow_mind)
	var/mob/living/carbon/human/S = shadow_mind.current
	shadow_mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/shadowling_hatch(null))
	shadow_mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/enthrall(null))
	shadow_mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/shadowling_hivemind(null))
	spawn(0)
		update_shadow_icons_added(shadow_mind)
		if(shadow_mind.assigned_role == "Clown")
			S << "<span class='notice'>Your alien nature has allowed you to overcome your clownishness.</span>"
			S.mutations.Remove(CLUMSY)

/datum/game_mode/proc/add_thrall(datum/mind/new_thrall_mind)
	if(!istype(new_thrall_mind))
		return 0
	if(!(new_thrall_mind in thralls))
		update_shadow_icons_added(new_thrall_mind)
		thralls += new_thrall_mind
		new_thrall_mind.special_role = "thrall"
		new_thrall_mind.current.attack_log += "\[[time_stamp()]\] <span class='danger'>Became a thrall</span>"
		new_thrall_mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/lesser_shadowling_hivemind(null))
		new_thrall_mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/lesser_glare(null))
		new_thrall_mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/lesser_shadow_walk(null))
		new_thrall_mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/thrall_vision(null))
		new_thrall_mind.current << "<span class='shadowling'><b>You see the truth. Reality has been torn away and you realize what a fool you've been.</b></span>"
		new_thrall_mind.current << "<span class='shadowling'><b>The shadowlings are your masters.</b> Serve them above all else and ensure they complete their goals.</span>"
		new_thrall_mind.current << "<span class='shadowling'>You may not harm other thralls or the shadowlings. However, you do not need to obey other thralls.</span>"
		new_thrall_mind.current << "<span class='shadowling'>Your body has been irreversibly altered. The attentive can see this - you may conceal it by wearing a mask.</span>"
		new_thrall_mind.current << "<span class='shadowling'>Though not nearly as powerful as your masters, you possess some weak powers. These can be found in the Thrall Abilities tab.</span>"
		new_thrall_mind.current << "<span class='shadowling'>You may communicate with your allies by using the Lesser Commune ability.</span>"
		return 1

/datum/game_mode/proc/remove_thrall(datum/mind/thrall_mind, var/kill = 0)
	if(!istype(thrall_mind) || !(thrall_mind in thralls) || !isliving(thrall_mind.current)) return 0 //If there is no mind, the mind isn't a thrall, or the mind's mob isn't alive, return
	update_shadow_icons_removed(thrall_mind)
	thralls.Remove(thrall_mind)
	thrall_mind.current.attack_log += "\[[time_stamp()]\] <span class='danger'>Dethralled</span>"
	thrall_mind.special_role = null
	for(var/obj/effect/proc_holder/spell/S in thrall_mind.spell_list)
		thrall_mind.remove_spell(S)
	if(kill && ishuman(thrall_mind.current)) //If dethrallization surgery fails, kill the mob as well as dethralling them
		var/mob/living/carbon/human/H = thrall_mind.current
		H.visible_message("<span class='warning'>[H] jerks violently and falls still.</span>", \
						  "<span class='userdanger'>A piercing white light floods your mind, banishing your memories as a thrall and--</span>")
		H.death()
		return 1
	var/mob/living/M = thrall_mind.current
	if(issilicon(M))
		M.audible_message("<span class='notice'>[M] lets out a short blip.</span>", \
						  "<span class='userdanger'>You have been turned into a robot! You are no longer a thrall! Though you try, you cannot remember anything about your servitude...</span>")
	else
		M.visible_message("<span class='big'>[M] looks like their mind is their own again!</span>", \
						  "<span class='userdanger'>A piercing white light floods your eyes. Your mind is your own again! Though you try, you cannot remember anything about the shadowlings or your time \
						  under their command...</span>")
	return 1

/datum/game_mode/proc/remove_shadowling(datum/mind/ling_mind)
	if(!istype(ling_mind) || !(ling_mind in shadows)) return 0
	update_shadow_icons_removed(ling_mind)
	shadows.Remove(ling_mind)
	ling_mind.current.attack_log += "\[[time_stamp()]\] <span class='danger'>Deshadowlinged</span>"
	ling_mind.special_role = null
	for(var/obj/effect/proc_holder/spell/S in ling_mind.spell_list)
		ling_mind.remove_spell(S)
	var/mob/living/M = ling_mind.current
	if(issilicon(M))
		M.audible_message("<span class='notice'>[M] lets out a short blip.</span>", \
						  "<span class='userdanger'>You have been turned into a robot! You are no longer a shadowling! Though you try, you cannot remember anything about your time as one...</span>")
	else
		M.visible_message("<span class='big'>[M] screams and contorts!</span>", \
						  "<span class='userdanger'>THE LIGHT-- YOUR MIND-- <i>BURNS--</i></span>")
		spawn(30)
			M.visible_message("<span class='warning'>[M] suddenly bloats and explodes!</span>", \
							  "<span class='warning'><b>AAAAAAAAA<font size=3>AAAAAAAAAAAAA</font><font size=4>AAAAAAAAAAAA----</font></span>")
			playsound(M, 'sound/magic/Disintegrate.ogg', 100, 1)
			M.gib()




/*
	GAME FINISH CHECKS
*/


/datum/game_mode/shadowling/check_finished()
	var/shadows_alive = 0 //and then shadowling was kill
	for(var/datum/mind/shadow in shadows) //but what if shadowling was not kill?
		if(!istype(shadow.current,/mob/living/carbon/human) && !istype(shadow.current,/mob/living/simple_animal/ascendant_shadowling))
			continue
		if(shadow.current.stat == DEAD)
			continue
		shadows_alive++
	if(shadows_alive)
		return ..()
	else
		shadowling_dead = 1 //but shadowling was kill :(
		return 1


/datum/game_mode/shadowling/proc/check_shadow_victory()
	var/success = 0 //Did they win?
	if(shadow_objectives.Find("enthrall"))
		success = shadowling_ascended
	return success



/datum/game_mode/shadowling/declare_completion()
	if(check_shadow_victory()) //Doesn't end instantly - this is hacky and I don't know of a better way ~X
		world << "<span class='greentext'><b>The shadowlings have ascended and taken over the station!</b></span>"
	else if(shadowling_dead && !check_shadow_victory()) //If the shadowlings have ascended, they can not lose the round
		world << "<span class='redtext'><b>The shadowlings have been killed by the crew!</b></span>"
	else if(!check_shadow_victory() )
		world << "<span class='redtext'><b>The crew escaped the station before the shadowlings could ascend!</b></span>"
	else
		world << "<span class='redtext'><b>The shadowlings have failed!</b></span>"
	..()
	return 1



/datum/game_mode/proc/auto_declare_completion_shadowling()
	var/text = ""
	if(shadows.len)
		text += "<br><span class='big'><b>The shadowlings were:</b></span>"
		for(var/datum/mind/shadow in shadows)
			text += printplayer(shadow)
		text += "<br>"
		if(thralls.len)
			text += "<br><span class='big'><b>The thralls were:</b></span>"
			for(var/datum/mind/thrall in thralls)
				text += printplayer(thrall)
	text += "<br>"
	world << text


/*
	MISCELLANEOUS
*/


/datum/species/shadow/ling
	//Normal shadowpeople but with enhanced effects
	name = "Shadowling"
	id = "shadowling"
	say_mod = "chitters"
	specflags = list(NOBREATH,NOBLOOD,RADIMMUNE,NOGUNS) //Can't use guns due to muzzle flash
	burnmod = 2 //2x burn damage lel
	heatmod = 2

/datum/species/shadow/ling/spec_life(mob/living/carbon/human/H)
	var/light_amount = 0
	H.nutrition = NUTRITION_LEVEL_WELL_FED //i aint never get hongry
	if(isturf(H.loc))
		var/turf/T = H.loc
		light_amount = T.get_lumcount()
		if(light_amount > LIGHT_DAM_THRESHOLD && !H.incorporeal_move) //Can survive in very small light levels. Also doesn't take damage while incorporeal, for shadow walk purposes
			H.take_overall_damage(0, LIGHT_DAMAGE_TAKEN)
			H << "<span class='userdanger'>The light burns you!</span>"
			H << 'sound/weapons/sear.ogg'
		else if (light_amount < LIGHT_HEAL_THRESHOLD)
			H.heal_overall_damage(5,5)
			H.adjustToxLoss(-5)
			H.adjustBrainLoss(-25) //Shad O. Ling gibbers, "CAN U BE MY THRALL?!!"
			H.adjustCloneLoss(-1)
			H.SetWeakened(0)
			H.SetStunned(0)

datum/species/shadow/ling/lesser //Empowered thralls. Obvious, but powerful
	name = "Lesser Shadowling"
	id = "l_shadowling"
	say_mod = "chitters"
	specflags = list(NOBREATH,NOBLOOD,RADIMMUNE)
	burnmod = 1.1
	heatmod = 1.1

/datum/species/shadow/ling/lesser/spec_life(mob/living/carbon/human/H)
	var/light_amount = 0
	H.nutrition = NUTRITION_LEVEL_WELL_FED //i aint never get hongry
	if(isturf(H.loc))
		var/turf/T = H.loc
		light_amount = T.get_lumcount()
		if(light_amount > LIGHT_DAM_THRESHOLD && !H.incorporeal_move)
			H.take_overall_damage(0, LIGHT_DAMAGE_TAKEN/2)
		else if (light_amount < LIGHT_HEAL_THRESHOLD)
			H.heal_overall_damage(2,2)
			H.adjustToxLoss(-5)
			H.adjustBrainLoss(-25)
			H.adjustCloneLoss(-1)


/obj/item/clothing/under/shadowling
	name = "blackened flesh"
	desc = "Black, chitinous skin."
	item_state = "golem"
	origin_tech = null
	icon_state = "golem"
	flags = ABSTRACT | NODROP
	has_sensor = 0
	unacidable = 1


/obj/item/clothing/suit/space/shadowling
	name = "chitin shell"
	desc = "A dark, semi-transparent shell. Protects against vacuum, but not against the light of the stars." //Still takes damage from spacewalking but is immune to space itself
	icon_state = "golem"
	item_state = "golem"
	body_parts_covered = FULL_BODY //Shadowlings are immune to space
	cold_protection = FULL_BODY
	min_cold_protection_temperature = SPACE_SUIT_MIN_TEMP_PROTECT
	flags_inv = HIDEGLOVES | HIDESHOES | HIDEJUMPSUIT
	flags = ABSTRACT | NODROP | THICKMATERIAL
	slowdown = 0
	unacidable = 1
	heat_protection = null //You didn't expect a light-sensitive creature to have heat resistance, did you?
	max_heat_protection_temperature = null


/obj/item/clothing/shoes/shadowling
	name = "chitin feet"
	desc = "Charred-looking feet. They have minature hooks that latch onto flooring."
	icon_state = "golem"
	unacidable = 1
	flags = NOSLIP | ABSTRACT | NODROP


/obj/item/clothing/mask/gas/shadowling
	name = "chitin mask"
	desc = "A mask-like formation with slots for facial features. A red film covers the eyes."
	icon_state = "golem"
	item_state = "golem"
	origin_tech = null
	siemens_coefficient = 0
	unacidable = 1
	flags = ABSTRACT | NODROP


/obj/item/clothing/gloves/shadowling
	name = "chitin hands"
	desc = "An electricity-resistant covering of the hands."
	icon_state = "golem"
	item_state = null
	origin_tech = null
	siemens_coefficient = 0
	unacidable = 1
	flags = ABSTRACT | NODROP


/obj/item/clothing/head/shadowling
	name = "chitin helm"
	desc = "A helmet-like enclosure of the head."
	icon_state = "golem"
	item_state = null
	cold_protection = HEAD
	min_cold_protection_temperature = SPACE_HELM_MIN_TEMP_PROTECT
	heat_protection = HEAD
	max_heat_protection_temperature = SPACE_HELM_MAX_TEMP_PROTECT
	origin_tech = null
	unacidable = 1
	flags = ABSTRACT | NODROP | STOPSPRESSUREDMAGE
	flags_inv = 0


/obj/item/clothing/glasses/night/shadowling
	name = "crimson eyes"
	desc = "A shadowling's eyes. Very light-sensitive and can detect body heat through walls."
	icon = null
	icon_state = null
	item_state = null
	origin_tech = null
	vision_flags = SEE_MOBS
	darkness_view = 1
	invis_view = 2
	flash_protect = -1
	unacidable = 1
	flags = ABSTRACT | NODROP
	action_button_name = "Shift Nerves"
	action_button_is_hands_free = 1
	var/max_darkness_view = 8
	var/min_darkness_view = 0

/obj/item/clothing/glasses/night/shadowling/attack_self(mob/user)
	if(!ishuman(user))
		return
	var/mob/living/carbon/human/H = user
	if(H.dna.species.id != "shadowling")
		user << "<span class='warning'>You aren't sure how to do this...</span>"
		return
	var/new_dark_view
	new_dark_view = (input(user, "Enter the radius of tiles to see with night vision.", "Night Vision", "[new_dark_view]") as num)
	new_dark_view = Clamp(new_dark_view,min_darkness_view,max_darkness_view)
	switch(new_dark_view)
		if(0)
			user << "<span class='notice'>Your night vision capabilities fade away for the time being.</span>"
		else
			user << "<span class='notice'>You shift your night vision capabilities to see [new_dark_view] tiles away.</span>"
	darkness_view = new_dark_view
	return

/obj/structure/shadow_vortex
	name = "vortex"
	desc = "A swirling hole in the fabric of reality. Eye-watering chimes sound from its depths."
	density = 0
	anchored = 1
	icon = 'icons/effects/genetics.dmi'
	icon_state = "shadow_portal"

/obj/structure/shadow_vortex/New()
	src.audible_message("<span class='warning'><b>\The [src] lets out a dismaying screech as dimensional barriers are torn apart!</span>")
	playsound(loc, 'sound/effects/supermatter.ogg', 100, 1)
	sleep(100)
	qdel(src)

/obj/structure/shadow_vortex/Crossed(var/td)
	..()
	if(ismob(td))
		td << "<span class='userdanger'>You enter the rift. Deafening chimes jingle in your ears. You are swallowed in darkness.</span>"
	playsound(loc, 'sound/effects/EMPulse.ogg', 25, 1)
	qdel(td)

// Hud datums for shadowlings and thralls
/datum/game_mode/proc/update_shadow_icons_added(datum/mind/shadow_mind)
	var/datum/atom_hud/antag/shadow_hud = huds[ANTAG_HUD_SHADOW]
	shadow_hud.join_hud(shadow_mind.current)
	set_antag_hud(shadow_mind.current, ((shadow_mind in shadows) ? "shadowling" : "thrall"))

/datum/game_mode/proc/update_shadow_icons_removed(datum/mind/shadow_mind) //This should never actually occur, but it's here anyway.
	var/datum/atom_hud/antag/shadow_hud = huds[ANTAG_HUD_SHADOW]
	shadow_hud.leave_hud(shadow_mind.current)
	set_antag_hud(shadow_mind.current, null)

/turf/proc/get_lumcount()
	var/light_amount
	if(!src || !istype(src)) return
	var/area/A = src.loc
	if(!A || !istype(src)) return
	if(A.lighting_use_dynamic) light_amount = src.lighting_lumcount
	else light_amount =  10
	return light_amount