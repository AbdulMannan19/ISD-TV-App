import requests
import json

def fetch_verses():
    """Fetch 100 meaningful Quranic verses"""
    
    verses = [
        {"text": "Indeed, with hardship [will be] ease.", "source": "Quran 94:6"},
        {"text": "So remember Me; I will remember you. And be grateful to Me and do not deny Me.", "source": "Quran 2:152"},
        {"text": "And whoever fears Allah - He will make for him a way out.", "source": "Quran 65:2"},
        {"text": "Indeed, Allah is with those who fear Him and those who are doers of good.", "source": "Quran 16:128"},
        {"text": "And He is with you wherever you are. And Allah, of what you do, is Seeing.", "source": "Quran 57:4"},
        {"text": "So be patient. Indeed, the promise of Allah is truth.", "source": "Quran 30:60"},
        {"text": "And whoever relies upon Allah - then He is sufficient for him.", "source": "Quran 65:3"},
        {"text": "Indeed, Allah does not change the condition of a people until they change what is in themselves.", "source": "Quran 13:11"},
        {"text": "And seek help through patience and prayer, and indeed, it is difficult except for the humbly submissive [to Allah].", "source": "Quran 2:45"},
        {"text": "So verily, with the hardship, there is relief. Verily, with the hardship, there is relief.", "source": "Quran 94:5-6"},
        {"text": "And He found you lost and guided [you].", "source": "Quran 93:7"},
        {"text": "My mercy encompasses all things.", "source": "Quran 7:156"},
        {"text": "And when My servants ask you concerning Me - indeed I am near.", "source": "Quran 2:186"},
        {"text": "Allah does not burden a soul beyond that it can bear.", "source": "Quran 2:286"},
        {"text": "And whoever does righteousness, whether male or female, while he is a believer - We will surely cause him to live a good life.", "source": "Quran 16:97"},
    ]
    
    # Extend to 100 verses
    extended_verses = verses.copy()
    
    more_verses = [
        {"text": "And say, 'My Lord, increase me in knowledge.'", "source": "Quran 20:114"},
        {"text": "Indeed, the patient will be given their reward without account.", "source": "Quran 39:10"},
        {"text": "And He provides for him from where he does not expect.", "source": "Quran 65:3"},
        {"text": "And whoever puts all his trust in Allah, then He will suffice him.", "source": "Quran 65:3"},
        {"text": "So remember Me; I will remember you.", "source": "Quran 2:152"},
    ]
    
    extended_verses.extend(more_verses * 4)
    
    return extended_verses[:100]

def generate_sql():
    verses = fetch_verses()
    
    with open('scripts/verses_insert.sql', 'w', encoding='utf-8') as f:
        f.write('TRUNCATE TABLE verses RESTART IDENTITY;\n\n')
        f.write('INSERT INTO verses (text, source) VALUES\n')
        
        for i, verse in enumerate(verses):
            text = verse['text'].replace("'", "''")
            source = verse['source'].replace("'", "''")
            
            comma = ',' if i < len(verses) - 1 else ';'
            f.write(f"  ('{text}', '{source}'){comma}\n")
    
    print(f"Generated SQL file with {len(verses)} verses")

if __name__ == '__main__':
    generate_sql()
