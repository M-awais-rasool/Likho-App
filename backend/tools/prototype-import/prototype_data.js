(function(){
const PAL={sun:['#FFC83D','#E0A21A','#FFEFC2'],sky:['#4D9DE0','#2F7CC0','#D6E9FA'],mint:['#3BB273','#268F58','#CDEFDB'],coral:['#FF8A5B','#E0673A','#FFDDCF'],grape:['#9B7FE6','#7659C9','#E5DCFB'],berry:['#F27BA6','#D2557F','#FCDCE8']};
const WORLDS=[
 {name:'Letter Land',skill:'Capital letters',bg:'#EAF5DE',accent:'#5DAE3B',deep:'#3F8A26',soft:'#D3ECBF',icon:'grass',boss:'Sust Ghonga'},
 {name:'Small Letter Cove',skill:'Small letters',bg:'#DFF3F1',accent:'#20A39D',deep:'#157C77',soft:'#BDE8E4',icon:'waves',boss:'Neend wali Machli'},
 {name:'Phonics Forest',skill:'Sounds & rhymes',bg:'#E3EEDB',accent:'#3F8F5A',deep:'#2C6B41',soft:'#C6DDB8',icon:'forest',boss:'Sota Bhaalu'},
 {name:'Word Town',skill:'Vocabulary',bg:'#FBEDE3',accent:'#DB7453',deep:'#B4573A',soft:'#F6D6C6',icon:'location_city',boss:'Robot-Bus'},
 {name:'Sentence Sky',skill:'Sentences',bg:'#E3F0FC',accent:'#3B89D2',deep:'#2767A5',soft:'#C8E1F7',icon:'cloud',boss:'Sota Baadal'},
 {name:'Story Space',skill:'Reading & speaking',bg:'#252950',accent:'#A08BF0',deep:'#7A63D4',soft:'#3A4077',icon:'rocket_launch',boss:'Neend mein Chaand',dark:true}];
const GUIDES={
 L:['M40 20 L40 70','M40 70 L64 70'], T:['M34 20 L66 20','M50 20 L50 70'],
 E:['M38 20 L38 70','M38 20 L62 20','M38 45 L58 45','M38 70 L62 70'], F:['M38 20 L38 70','M38 20 L62 20','M38 45 L58 45'],
 H:['M36 20 L36 70','M64 20 L64 70','M36 45 L64 45'], A:['M50 20 L32 70','M50 20 L68 70','M39 52 L61 52'],
 C:['M66 28 A22 25 0 1 0 66 62'], O:['M50 20 A20 25 0 1 0 50 70 A20 25 0 1 0 50 20'],
 S:['M64 28 C60 19 38 18 38 31 C38 44 62 42 62 57 C62 72 40 72 36 62'], U:['M34 20 L34 52 A16 18 0 0 0 66 52 L66 20'],
 J:['M60 20 L60 56 A12 14 0 0 1 36 58'],
 c:['M60 50 A12.5 12.5 0 1 0 60 65'], o:['M50 45 A12.5 12.5 0 1 0 50 70 A12.5 12.5 0 1 0 50 45'],
 a:['M60 50 A12.5 12.5 0 1 0 60 65','M62.5 45 L62.5 70'], d:['M60 50 A12.5 12.5 0 1 0 60 65','M62.5 20 L62.5 70'],
 g:['M60 50 A12.5 12.5 0 1 0 60 65','M62.5 45 L62.5 80 A11 10 0 0 1 41 83']};
const PK=(say,card,opts,ans,x)=>Object.assign({t:'pick',say,card,opts,ans},x||{});
const WR=(say,mode,g,x)=>Object.assign({t:'write',say,mode,g},x||{});
const OR=(say,card,tiles,x)=>Object.assign({t:'order',say,card,tiles},x||{});
const SP=(say,card)=>({t:'speak',say,card});
const L=(name,skill,icon,cfg,rounds)=>Object.assign({name,skill,icon,rounds},cfg);
const rot=(a,k)=>a.slice(k).concat(a.slice(0,k));
const paint=[['red','#F2735B'],['blue','#4D9DE0'],['yellow','#FFC83D'],['green','#3BB273'],['purple','#9B7FE6']];
const st1='Sam has a red ball. He plays in the park.', st2='Mia sees a big fish in the sea.';
const LEVELS=[
 L('Warm-up','Placement','self_improvement',{shape:'balloon',intro:'A',introWord:'warm-up'},[WR('Trace A','trace','A',{card:{pic:'apple',m:'A'}}),PK('Find M!',{m:'M'},['N','M','W'],'M'),WR('Write b','free','b',{card:{ear:1,m:'b'}})]),
 L('Balloon Pop','Letter names','celebration',{shape:'balloon',intro:'B',introWord:'balloon'},[PK('Find B!',{m:'B'},['D','B','P','R'],'B'),PK('Find M!',{m:'M'},['M','N','W','H'],'M'),PK('Find S!',{m:'S'},['Z','C','S','O'],'S'),PK('Find A!',{m:'A'},['H','A','V','K'],'A'),PK('Find T!',{m:'T'},['I','L','F','T'],'T')]),
 L('Alphabet Train','Alphabet order','train',{slot:'wagon',intro:'ABC',introWord:'train'},[['A','B','C'],['D','E','F'],['G','H','I','J'],['K','L','M','N'],['O','P','Q','R']].map(t=>OR('Fill the train!',{pic:'train',m:t[0]+' → '+t[t.length-1]},t))),
 L('Straight Tracks','Straight lines','directions_railway',{pad:'track',intro:'L',introWord:'lion'},[WR('Trace L','trace','L',{card:{pic:'lion',m:'L'}}),WR('Trace T','trace','T',{card:{pic:'tiger',m:'T'}}),WR('Join E','dots','E',{card:{pic:'egg',m:'E'}}),WR('Join F','dots','F',{card:{pic:'fish',m:'F'}}),WR('Trace H','trace','H',{card:{pic:'hat',m:'H'}})]),
 L('Curvy Roads','Round letters','route',{pad:'road',intro:'C',introWord:'car'},[['C','car'],['O','orange'],['S','sun'],['U','umbrella'],['J','jam']].map(([c,p])=>WR('Trace '+c,'trace',c,{card:{pic:p,m:c}}))),
 L('Sound Fishing','Letter sounds','phishing',{shape:'fish',intro:'F',introWord:'fish'},[PK('/b/',{ear:1,m:'/b/'},['B','D','M'],'B'),PK('/m/',{ear:1,m:'/m/'},['N','M','S'],'M'),PK('/s/',{ear:1,m:'/s/'},['T','A','S'],'S'),PK('/t/',{ear:1,m:'/t/'},['T','P','F'],'T'),PK('/p/',{ear:1,m:'/p/'},['R','B','P'],'P')]),
 L('Wake the Snail','Boss · capitals','bedtime',{boss:true,intro:'A B C',introWord:'snail'},'ABCDE'.split('').map(c=>WR('Write '+c,'free',c,{card:{ear:1,m:c}}))),
 L('Shell Pairs','Capital + small','spa',{shape:'shell',intro:'Aa',introWord:'shell'},[PK('Find a',{m:'A'},['a','e','o'],'a'),PK('Find b',{m:'B'},['d','b','p'],'b'),PK('Find d',{m:'D'},['b','q','d'],'d'),PK('Find g',{m:'G'},['q','g','p'],'g'),PK('Find e',{m:'E'},['e','a','c'],'e')]),
 L('Sand Writing','Small letters','beach_access',{pad:'sand',intro:'a',introWord:'sand'},[['c','cup'],['a','ant'],['d','duck'],['o','owl'],['g','goat']].map(([c,p])=>WR('Trace '+c,'trace',c,{card:{pic:p,m:c}}))),
 L('b or d?','Tricky letters','bubble_chart',{shape:'bubble',intro:'b d',introWord:'bubble'},[PK('Tap b!',{ear:1,m:'b'},['d','b','p','q'],'b'),PK('Tap d!',{ear:1,m:'d'},['b','q','d','p'],'d'),PK('Tap p!',{ear:1,m:'p'},['q','d','b','p'],'p'),PK('Tap q!',{ear:1,m:'q'},['p','q','b','d'],'q'),PK('Tap d!',{ear:1,m:'d'},['d','b','p','q'],'d')]),
 L('Crab Sort','Letter shapes','shopping_basket',{shape:'basket',intro:'h',introWord:'crab'},['h','o','y','k','e'].map(c=>PK('Sort '+c,{m:c},['b d h','a c e','g p y'],/[bdhkl]/.test(c)?'b d h':/[gpyq]/.test(c)?'g p y':'a c e'))),
 L('Bottle Message','Alphabet gaps','mail',{intro:'a b c',introWord:'bottle'},[['abcd',2],['efgh',2],['lmno',1],['pqrs',2],['uvwx',2]].map(([w,m])=>WR('What comes next?','missing',w[m],{word:w,miss:m,card:{pic:'bottle message'}}))),
 L('Wake the Fish','Boss · small letters','bedtime',{boss:true,intro:'a m s',introWord:'fish'},'amste'.split('').map(c=>WR('Write '+c,'free',c,{card:{ear:1,m:c}}))),
 L('Mushroom Sounds','First sounds','forest',{shape:'mushroom',intro:'a',introWord:'apple'},[['apple','a',['a','m','s','t']],['sun','s',['b','s','o','f']],['moon','m',['n','w','m','u']],['fish','f',['t','h','l','f']],['dog','d',['b','p','d','g']]].map(([p,a,o])=>PK(p,{pic:p},o,a))),
 L('Rhyme Frogs','Rhyming','pets',{shape:'pad',intro:'-at',introWord:'frog'},[['cat','hat',['hat','dog','sun']],['dog','log',['cup','log','bee']],['sun','bun',['bun','car','pig']],['bee','tree',['box','hen','tree']],['car','star',['star','cat','egg']]].map(([w,a,o])=>PK(w,{pic:w,m:w},o.map(l=>({l,pic:l})),a))),
 L('Blend Bridge','Blending','linear_scale',{slot:'plank',intro:'c-a-t',introWord:'bridge'},['cat','dog','sun','pig','hen'].map(w=>OR(w,{pic:w},w.split('')))),
 L('Vowel Owl','Vowels','visibility',{intro:'a e i',introWord:'owl'},['cat','dog','sun','pig','bed'].map(w=>WR(w[0]+' _ '+w[2],'missing',w[1],{word:w,miss:1,card:{pic:w}}))),
 L('Firefly Claps','Syllables','emoji_objects',{shape:'jar',intro:'ba·na·na',introWord:'firefly'},[['banana',3],['cat',1],['apple',2],['tiger',2],['butterfly',3]].map(([w,n])=>PK(w,{pic:w,m:w},['1','2','3'],String(n)))),
 L('Wake the Bear','Boss · CVC words','bedtime',{boss:true,intro:'dog',introWord:'bear'},['dog','sun','pig','cat','hen'].map(w=>WR(w,'spell',w,{word:w,card:{ear:1,pic:w}}))),
 L('Paint Shop','Colors','format_paint',{shape:'bucket',intro:'red',introWord:'paint',stage:'house'},paint.map(([w,c],i)=>PK(w,{m:w},rot([paint[i],paint[(i+2)%5],paint[(i+4)%5]],i%3).map(([l,color])=>({l,color,noLabel:1})),w))),
 L('Zoo Bus','Animals','directions_bus',{shape:'card',intro:'cow',introWord:'zoo bus'},[['Moo!','cow',['cow','duck','cat']],['Quack!','duck',['dog','duck','pig']],['Meow!','cat',['pig','cow','cat']],['Woof!','dog',['dog','cat','duck']],['Oink!','pig',['cow','pig','dog']]].map(([s,a,o])=>PK(s,{ear:1,m:s},o.map(l=>({l,pic:l})),a))),
 L('Doctor Pencil','Body parts','medical_services',{layout:'patient',intro:'nose',introWord:'doctor'},['nose','eye','ear','mouth','hand'].map(p=>PK('Touch the '+p+'!',{m:p},['nose','eye','ear','mouth','hand'],p))),
 L('Cupcake Count','Numbers','cake',{shape:'card',intro:'1 2 3',introWord:'cupcake',stage:'count'},[[3,['two','three','five']],[4,['four','six','one']],[2,['two','seven','three']],[5,['one','five','four']],[1,['three','one','two']]].map(([n,o])=>PK('How many?',{m:'How many?'},o,['one','two','three','four','five'][n-1],{count:n}))),
 L('Family Album','Family words','photo_library',{shape:'card',intro:'mum',introWord:'family'},[['mother',['mother','father','baby']],['father',['sister','father','brother']],['baby',['baby','mother','sister']],['sister',['brother','baby','sister']],['brother',['brother','father','mother']]].map(([a,o])=>PK('Who is this?',{pic:'photo: '+a},o,a))),
 L('Wake the Robot-Bus','Boss · words','bedtime',{boss:true,intro:'bus',introWord:'robot-bus'},['bus','hat','cup','sun','cat'].map(w=>WR(w,'spell',w,{word:w,card:{pic:w}}))),
 L('Sight Word Kites','Sight words','air',{shape:'kite',intro:'the',introWord:'kite'},[['the',['the','is','and','see']],['is',['can','is','the','and']],['and',['see','and','is','can']],['see',['the','can','see','is']],['can',['and','see','the','can']]].map(([a,o])=>PK(a,{ear:1,m:a},o,a))),
 L('a or an?','Articles','cloud',{shape:'cloud',intro:'an',introWord:'apple'},[['apple','an'],['ball','a'],['egg','an'],['dog','a'],['owl','an']].map(([w,a])=>PK('__ '+w,{pic:w,m:'__ '+w},['a','an'],a))),
 L('One or Many','Plurals','flutter_dash',{intro:'-s',introWord:'birds'},['birds','cats','dogs','cups','hats'].map(w=>WR(w.slice(0,-1)+' → many','missing','s',{word:w,miss:w.length-1,card:{pic:'many '+w}}))),
 L('Sentence Rainbow','Word order','looks',{slot:'stripe',intro:'I see',introWord:'rainbow'},[['I','see','a','cat'],['I','can','run'],['The','sun','is','hot'],['I','like','red'],['We','can','play']].map(t=>OR(t.join(' '),{ear:1,pic:t[t.length-1]},t))),
 L('Fix-It Pencil','Capitals','edit',{layout:'flow',intro:'I.',introWord:'pencil'},['i see a dog','we can run','the cat is big','my dog is fun','i like cake'].map(s=>{const t=s.split(' ');return PK('Fix it!',{m:'Fix it!'},t,t[0],{fix:1})})),
 L('Wake the Cloud','Boss · sentences','bedtime',{boss:true,intro:'I see',introWord:'cloud'},['I see a cat.','I can run.','The sun is up.','I like red.','We can play.'].map(s=>WR(s,'free',s,{card:{ear:1,m:s},sentence:1}))),
 L('Read & Match','Reading','public',{shape:'planet',intro:'read',introWord:'planet'},[['The cat is on the box.','cat on box',['cat on box','cat in bed','dog on box']],['The dog can run.','dog running',['dog asleep','dog running','cat running']],['The sun is hot.','hot sun',['rain cloud','moon','hot sun']],['I see a red car.','red car',['red car','blue car','red bus']],['The fish is in the sea.','fish in sea',['bird in sky','fish in sea','fish in bowl']]].map(([s,a,o])=>PK(s,{m:s},o.map(l=>({l,pic:l})),a))),
 L('Talk to Aliens','Speaking','record_voice_over',{layout:'alien',intro:'Hi!',introWord:'alien'},['What is your name?','How old are you?','What color do you like?','Do you have a pet?','Say goodbye!'].map(q=>SP(q,{ear:1,m:q}))),
 L('Story Order','Sequencing','view_carousel',{slot:'panel',intro:'1 2 3',introWord:'story'},[['seed','sprout','flower'],['egg','crack','chick'],['cloud','rain','puddle'],['dough','oven','bread'],['wake up','eat','school']].map(t=>OR('Put in order',{m:'1 · 2 · 3'},t))),
 L('Star Questions','Comprehension','auto_awesome',{shape:'card',intro:'Who?',introWord:'story',stage:'stars'},[PK('Who has a ball?',{m:st1},['Sam','Mia','Tom'],'Sam'),PK('What does Sam have?',{m:st1},['kite','ball','bat'],'ball'),PK('Where does he play?',{m:st1},['school','home','park'],'park'),PK('Who sees a fish?',{m:st2},['Dad','Mia','Sam'],'Mia'),PK('Where is the fish?',{m:st2},['sea','tree','car'],'sea')]),
 L('My Story','Creative writing','auto_stories',{shape:'card',intro:'My…',introWord:'storybook'},[PK('Choose a friend',{m:'Friend?'},[{l:'cat',pic:'cat'},{l:'robot',pic:'robot'},{l:'dragon',pic:'dragon'}],'*',{key:'who'}),PK('Choose a place',{m:'Where?'},[{l:'moon',pic:'moon'},{l:'sea',pic:'sea'},{l:'forest',pic:'forest'}],'*',{key:'where'}),PK('Choose a thing',{m:'What?'},[{l:'kite',pic:'kite'},{l:'cake',pic:'cake'},{l:'hat',pic:'hat'}],'*',{key:'what'}),WR('Write your story','free','',{card:{m:'My cat can fly.'},sentence:1,story:1})]),
 L('Wake the Moon','Boss · final','dark_mode',{boss:true,intro:'★',introWord:'moon'},[PK('The cat is on the box.',{m:'The cat is on the box.'},[{l:'cat on box',pic:'cat on box'},{l:'cat in bed',pic:'cat in bed'}],'cat on box',{shape:'planet'}),WR('moon','spell','moon',{word:'moon',card:{ear:1,pic:'moon'}}),SP('Say: I love to read!',{m:'I love to read!'}),PK('Who has a kite?',{m:'Ali has a kite. Sara has a ball.'},['Ali','Sara','Sam'],'Ali',{shape:'card'}),WR('I can read.','free','',{card:{ear:1,m:'I can read.'},sentence:1})])
];
const ITEMS=[
 {id:'party',slot:'hat',name:'Party topi',price:8,kind:'wear'},{id:'beanie',slot:'hat',name:'Oon topi',price:12,kind:'wear'},
 {id:'tophat',slot:'hat',name:'Lambi topi',price:20,kind:'wear'},{id:'round',slot:'eyes',name:'Gol chashma',price:10,kind:'wear'},
 {id:'shades',slot:'eyes',name:'Dhoop chashma',price:15,kind:'wear'},{id:'scarf',slot:'neck',name:'Muffler',price:12,kind:'wear'},
 {id:'cape',slot:'back',name:'Cape',price:25,kind:'wear'},{id:'crown',slot:'hat',name:'Taaj',price:40,kind:'wear'},
 {id:'phones',slot:'ears',name:'Headphones',price:18,kind:'wear'},{id:'bow',slot:'bow',name:'Bow',price:6,kind:'wear'},
 {id:'lamp',name:'Lamp',price:10,kind:'room',icon:'emoji_objects'},{id:'poster',name:'Poster',price:14,kind:'room',icon:'image'},
 {id:'plant',name:'Paudha',price:8,kind:'room',icon:'potted_plant'},{id:'rug',name:'Qaleen',price:16,kind:'room',icon:'blur_circular'}];
window.LIKHO={PAL,WORLDS,GUIDES,LEVELS,ITEMS};
})();
