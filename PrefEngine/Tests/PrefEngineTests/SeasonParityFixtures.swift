// Golden transcripts produced by running ANDROID's own engine (model + ai,
// compiled unmodified with Kotlin 2.2.20 on a JVM) with every seat on the bots:
// one line per deal, including the bot RNG state after each deal, which pins the
// exact number of random draws the AI consumed. SeasonTests replays the same
// seasons on the Swift engine and requires an identical transcript.
// Regenerate with tools/parity/run_parity.sh when Android's engine or AI changes.
enum SeasonParityFixtures {
    static let transcript_parity_seed_02 = """
CONFIG limit=10 type=Leningrad prog=Geom1244 exit=Hard678 dealer=0
P0 D0 Normal c=0 k=6 t=4,4,2 v=2 d=0 m=1 rng=1652290463649026734 idx=1
P0 D1 Miser c=1 k=6 t=2,0,8 v= d=1 m=1 rng=7679649112822167245 idx=2
POOL 0 deals=2 steps=62 fallbacks=0 sheet=[0/8/1=0,2=0] [10/0/0=8,2=0] [0/0/0=32,1=0] settlement10=-1600,1680,-80
P1 D0 Normal c=0 k=7 t=8,0,2 v=2 d=2 m=1 rng=6103250833234365034 idx=3
P1 D1 Normal c=0 k=6 t=6,1,3 v=2 d=0 m=1 rng=452169398004767510 idx=4
P1 D2 Normal c=1 k=6 t=4,6,0 v=0 d=1 m=1 rng=-575738425647757085 idx=5
P1 D3 Normal c=0 k=7 t=8,1,1 v=2 d=2 m=1 rng=52878694196537484 idx=6
POOL 1 deals=4 steps=114 fallbacks=0 sheet=[10/0/1=16,2=0] [2/0/0=0,2=0] [0/0/0=48,1=0] settlement10=880,-560,-320
P2 D0 Raspasy c=0 k=0 t=4,4,2 v= d=0 m=1 rng=6308317727859245179 idx=7
P2 D1 Normal c=2 k=7 t=3,1,6 v=1 d=1 m=2 rng=3855049199898603849 idx=8
P2 D2 Raspasy c=2 k=7 t=2,5,3 v= d=1 m=2 rng=2231060086501374626 idx=9
P2 D3 Raspasy c=2 k=7 t=3,0,7 v= d=2 m=4 rng=704178098978596972 idx=10
P2 D4 Raspasy c=2 k=7 t=2,4,4 v= d=0 m=4 rng=2353753211159233077 idx=11
P2 D5 Raspasy c=2 k=7 t=2,2,6 v= d=1 m=4 rng=-1552042723489155461 idx=12
P2 D6 Normal c=2 k=9 t=0,1,9 v=1 d=2 m=4 rng=-6172402546519964982 idx=13
POOL 2 deals=7 steps=145 fallbacks=0 sheet=[0/28/1=0,2=8] [4/32/0=0,2=56] [8/116/0=0,1=0] settlement10=2347,3227,-5573
TOTAL total10=1627 pools=3 next=13 dealer=0
"""

    static let transcript_parity_seed_05 = """
CONFIG limit=20 type=Leningrad prog=Geom1244 exit=Hard678 dealer=0
P0 D0 Raspasy c=0 k=0 t=6,2,2 v= d=0 m=1 rng=1441496554254488290 idx=1
P0 D1 Raspasy c=0 k=0 t=3,6,1 v= d=1 m=2 rng=-3707876126639609695 idx=2
P0 D2 Raspasy c=0 k=0 t=5,3,2 v= d=2 m=4 rng=5772133843305721987 idx=3
P0 D3 Raspasy c=0 k=0 t=6,1,3 v= d=0 m=4 rng=-8318723590462761392 idx=4
P0 D4 Raspasy c=0 k=0 t=2,4,4 v= d=1 m=4 rng=5154355355916665380 idx=5
P0 D5 Raspasy c=0 k=0 t=4,2,4 v= d=2 m=4 rng=8987099301163717080 idx=6
P0 D6 Raspasy c=0 k=0 t=5,1,4 v= d=0 m=4 rng=-6697421106260190907 idx=7
P0 D7 Raspasy c=0 k=0 t=4,3,3 v= d=1 m=4 rng=-6373504833954817302 idx=8
P0 D8 Raspasy c=0 k=0 t=1,7,2 v= d=2 m=4 rng=-5151370198611554835 idx=9
P0 D9 Raspasy c=0 k=0 t=3,1,6 v= d=0 m=4 rng=-3002974159301526053 idx=10
P0 D10 Raspasy c=0 k=0 t=3,4,3 v= d=1 m=4 rng=239784424034397288 idx=11
P0 D11 Raspasy c=0 k=0 t=7,2,1 v= d=2 m=4 rng=-2759533931242831554 idx=12
P0 D12 Raspasy c=0 k=0 t=1,3,6 v= d=0 m=4 rng=-6654846212963702825 idx=13
P0 D13 Raspasy c=0 k=0 t=1,2,7 v= d=1 m=4 rng=21364538041955253 idx=14
P0 D14 Raspasy c=0 k=0 t=4,1,5 v= d=2 m=4 rng=8159788847974470393 idx=15
P0 D15 Raspasy c=0 k=0 t=5,4,1 v= d=0 m=4 rng=-6824870586218282119 idx=16
P0 D16 Raspasy c=0 k=0 t=3,3,4 v= d=1 m=4 rng=-1199649926265442295 idx=17
P0 D17 Raspasy c=0 k=0 t=1,6,3 v= d=2 m=4 rng=-8361725475620187200 idx=18
P0 D18 Raspasy c=0 k=0 t=1,0,9 v= d=0 m=4 rng=-5678934386982028362 idx=19
P0 D19 Raspasy c=0 k=0 t=6,4,0 v= d=1 m=4 rng=4939087521365786797 idx=20
P0 D20 Raspasy c=0 k=0 t=3,4,3 v= d=2 m=4 rng=-4299761190434463593 idx=21
P0 D21 Raspasy c=0 k=0 t=3,3,4 v= d=0 m=4 rng=6794359769367481188 idx=22
P0 D22 Raspasy c=0 k=0 t=4,3,3 v= d=1 m=4 rng=-5445362655935089637 idx=23
P0 D23 Raspasy c=0 k=0 t=2,6,2 v= d=2 m=4 rng=-5277063299386975210 idx=24
P0 D24 Raspasy c=0 k=0 t=4,3,3 v= d=0 m=4 rng=6699042315828444640 idx=25
P0 D25 Raspasy c=0 k=0 t=1,2,7 v= d=1 m=4 rng=-8902225717654876844 idx=26
P0 D26 Raspasy c=0 k=0 t=2,4,4 v= d=2 m=4 rng=4839276573894504925 idx=27
P0 D27 Raspasy c=0 k=0 t=4,0,6 v= d=0 m=4 rng=759989931763872364 idx=28
P0 D28 Raspasy c=0 k=0 t=4,0,6 v= d=1 m=4 rng=-1472396129709161130 idx=29
P0 D29 Raspasy c=0 k=0 t=6,3,1 v= d=2 m=4 rng=-298032779568745868 idx=30
P0 D30 Raspasy c=0 k=0 t=1,0,9 v= d=0 m=4 rng=2029867320379616973 idx=31
POOL 0 deals=31 steps=713 fallbacks=0 sheet=[0/440/1=0,2=0] [16/308/0=0,2=0] [4/576/0=0,1=0] settlement10=-1200,15200,-14000
P1 D0 Normal c=0 k=6 t=5,2,3 v=2 d=1 m=1 rng=-4193558128131746098 idx=32
P1 D1 Raspasy c=0 k=6 t=3,1,6 v= d=2 m=1 rng=-2220006707698055830 idx=33
P1 D2 Normal c=0 k=7 t=6,3,1 v=2 d=0 m=2 rng=4700004206639310447 idx=34
P1 D3 Raspasy c=0 k=7 t=2,2,6 v= d=0 m=2 rng=1906242275606515895 idx=35
P1 D4 Raspasy c=0 k=7 t=1,2,7 v= d=1 m=4 rng=-3708307789131331832 idx=36
P1 D5 Raspasy c=0 k=7 t=1,8,1 v= d=2 m=4 rng=7234863273808631780 idx=37
P1 D6 Raspasy c=0 k=7 t=6,4,0 v= d=0 m=4 rng=-8677544700490175858 idx=38
P1 D7 Raspasy c=0 k=7 t=1,7,2 v= d=1 m=4 rng=8069309830082583300 idx=39
P1 D8 Raspasy c=0 k=7 t=0,4,6 v= d=2 m=4 rng=7453179534865983581 idx=40
P1 D9 Raspasy c=0 k=7 t=7,2,1 v= d=0 m=4 rng=2799021347524910826 idx=41
P1 D10 Raspasy c=0 k=7 t=2,5,3 v= d=1 m=4 rng=924126330806947074 idx=42
P1 D11 Raspasy c=0 k=7 t=4,4,2 v= d=2 m=4 rng=-112786050562294497 idx=43
P1 D12 Raspasy c=0 k=7 t=7,0,3 v= d=0 m=4 rng=-6740045542531723712 idx=44
P1 D13 Raspasy c=0 k=7 t=9,0,1 v= d=1 m=4 rng=-7659003531680858297 idx=45
P1 D14 Raspasy c=0 k=7 t=1,5,4 v= d=2 m=4 rng=-3614214057580691384 idx=46
P1 D15 Normal c=1 k=8 t=0,8,2 v=0 d=0 m=4 rng=-2940444904414117204 idx=47
POOL 1 deals=16 steps=387 fallbacks=0 sheet=[4/256/1=24,2=0] [14/256/0=12,2=0] [4/194/0=64,1=0] settlement10=-3253,-853,4107
P2 D0 Raspasy c=0 k=0 t=0,9,1 v= d=1 m=1 rng=-1478198780885419631 idx=48
P2 D1 Raspasy c=0 k=0 t=3,3,4 v= d=2 m=2 rng=-6205918416998078133 idx=49
P2 D2 Raspasy c=0 k=0 t=2,3,5 v= d=0 m=4 rng=-4844630607149463061 idx=50
P2 D3 Raspasy c=0 k=0 t=4,6,0 v= d=1 m=4 rng=3130274134034196565 idx=51
P2 D4 Raspasy c=0 k=0 t=7,0,3 v= d=2 m=4 rng=-3689284966211307220 idx=52
P2 D5 Raspasy c=0 k=0 t=2,4,4 v= d=0 m=4 rng=8205044079680664202 idx=53
P2 D6 Raspasy c=0 k=0 t=7,1,2 v= d=1 m=4 rng=7215789885953709211 idx=54
P2 D7 Raspasy c=0 k=0 t=7,2,1 v= d=2 m=4 rng=5758976322303394249 idx=55
P2 D8 Raspasy c=0 k=0 t=0,5,5 v= d=0 m=4 rng=3935964536414718987 idx=56
P2 D9 Raspasy c=0 k=0 t=3,4,3 v= d=1 m=4 rng=-603650463889128235 idx=57
P2 D10 Raspasy c=0 k=0 t=5,5,0 v= d=2 m=4 rng=-6645831083823503914 idx=58
P2 D11 Raspasy c=0 k=0 t=3,5,2 v= d=0 m=4 rng=-8314975057679726135 idx=59
P2 D12 Raspasy c=0 k=0 t=0,3,7 v= d=1 m=4 rng=-2324344511112747644 idx=60
POOL 2 deals=13 steps=299 fallbacks=0 sheet=[9/232/1=0,2=0] [4/234/0=0,2=0] [8/174/0=0,1=0] settlement10=-1467,-2667,4133
TOTAL total10=-5920 pools=3 next=60 dealer=2
"""
}
